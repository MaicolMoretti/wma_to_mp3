import Foundation
import CoreGraphics
import VideoToolbox

//autore: Maicol Moretti
/// Analizzatore di fotogrammi video per il rilevamento di schermate blu con testo bianco.
struct VideoAnalyzer {
    
    /// Configurazione per il rilevamento calibrata sull'immagine reale fornita dall'utente.
    /// La schermata di riferimento è un blu SCURO e NON UNIFORME (ha elementi decorativi:
    /// cerchio watermark, linee cyan-bianche, logo università) che riducono la % di blu puro.
    struct Thresholds {
        // Hue range blu: 160°-270° copre blu navy, blu medio e un po' di cyan
        static let minHue: CGFloat = 160.0 / 360.0
        static let maxHue: CGFloat = 270.0 / 360.0
        static let minSaturation: CGFloat = 0.15
        static let minValue: CGFloat = 0.10
        
        // Soglia alzata al 45%: con il fix BGR->RGB siamo più precisi, possiamo essere più selettivi.
        static let bluePixelPercentage: Double = 0.45
        
        // Luminosità minima per il testo bianco centrale
        static let whiteTextBrightness: CGFloat = 0.55
    }

    /// Normalizza l'immagine in formato RGBA garantito su un CGContext.
    /// CRITICO: AVAssetImageGenerator restituisce immagini in formato BGRA (macOS little-endian),
    /// non RGBA. Senza questa normalizzazione, i canali R e B risultano invertiti
    /// e un pixel blu viene interpretato come rosso dall'algoritmo HSV.
    private static func normalizeToRGBA(_ image: CGImage) -> (data: [UInt8], width: Int, height: Int, bytesPerRow: Int)? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        
        // Uso un buffer di pixel singolo per ridurre le allocazioni
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixelData, width, height, bytesPerRow)
    }

    /// Analizza un'immagine per determinare se è una schermata blu di delimitazione.
    /// IMPLEMENTAZIONE OTTIMIZZATA:
    /// 1. Usa pointer diretti ai pixel per evitare overhead di copia.
    /// 2. Applica 'Blue Dominance' per filtrare falsi positivi (es. vestiti azzurri).
    /// 3. Verifica uniformità verticale (Top/Bottom 10%) per garantire che sia una schermata a pieno schermo.
    static func isBlueScreen(_ image: CGImage) -> Bool {
        guard let (pixels, width, height, bytesPerRow) = normalizeToRGBA(image) else {
            return false
        }
        
        var totalBluePixels = 0
        var topBluePixels = 0
        var bottomBluePixels = 0
        
        let step = 4
        var sampledTotal = 0
        var sampledTop = 0
        var sampledBottom = 0
        
        let topBoundary = Int(Double(height) * 0.10)
        let bottomBoundary = Int(Double(height) * 0.90)
        
        // Ottimizzazione: accesso diretto ai pixel come puntatori per massimizzare la velocità
        pixels.withUnsafeBufferPointer { ptr in
            for y in stride(from: 0, to: height, by: step) {
                let rowOffset = y * bytesPerRow
                for x in stride(from: 0, to: width, by: step) {
                    let offset = rowOffset + x * 4
                    let rVal = ptr[offset]
                    let gVal = ptr[offset + 1]
                    let bVal = ptr[offset + 2]
                    
                    // Dominanza Blu Rapida (Security/Performance: primo filtro veloce)
                    // Il blu deve essere significativamente superiore agli altri canali
                    guard bVal > 40 && bVal > rVal && bVal > gVal else {
                        sampledTotal += 1
                        if y < topBoundary { sampledTop += 1 }
                        if y > bottomBoundary { sampledBottom += 1 }
                        continue
                    }
                    
                    let r = CGFloat(rVal) / 255.0
                    let g = CGFloat(gVal) / 255.0
                    let b = CGFloat(bVal) / 255.0
                    
                    let hsv = rgbToHsv(r: r, g: g, b: b)
                    
                    let isInHue = hsv.h >= Thresholds.minHue && hsv.h <= Thresholds.maxHue
                    let isSaturated = hsv.s >= Thresholds.minSaturation
                    let isBright = hsv.v >= Thresholds.minValue
                    
                    // Dominanza Blu (Elimina grigi, viola e azzurrini spuri)
                    let isBlueDominant = (Float(bVal) > Float(rVal) * 1.4) && (Float(bVal) > Float(gVal) * 1.4)
                    
                    if isInHue && isSaturated && isBright && isBlueDominant {
                        totalBluePixels += 1
                        if y < topBoundary { topBluePixels += 1 }
                        if y > bottomBoundary { bottomBluePixels += 1 }
                    }
                    
                    sampledTotal += 1
                    if y < topBoundary { sampledTop += 1 }
                    if y > bottomBoundary { sampledBottom += 1 }
                }
            }
        }
        
        let blueRatio = Double(totalBluePixels) / Double(sampledTotal)
        let topRatio = sampledTop > 0 ? Double(topBluePixels) / Double(sampledTop) : 0
        let bottomRatio = sampledBottom > 0 ? Double(bottomBluePixels) / Double(sampledBottom) : 0
        
        if blueRatio > Thresholds.bluePixelPercentage && topRatio > 0.3 && bottomRatio > 0.3 {
            return hasCenterWhiteText(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
        }
        
        return false
    }
    
    /// Verifica se c'è una regione luminosa (testo bianco) nel centro dell'immagine.
    private static func hasCenterWhiteText(pixels: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> Bool {
        let cxStart = Int(Double(width) * 0.1)
        let cxEnd   = Int(Double(width) * 0.8)
        let cyStart = Int(Double(height) * 0.30)
        let cyEnd   = Int(Double(height) * 0.70)
        
        var brightPixels = 0
        var monitoredPixels = 0
        
        pixels.withUnsafeBufferPointer { ptr in
            for y in stride(from: cyStart, to: cyEnd, by: 3) {
                let rowOffset = y * bytesPerRow
                for x in stride(from: cxStart, to: cxEnd, by: 3) {
                    let offset = rowOffset + x * 4
                    let r = CGFloat(ptr[offset])     / 255.0
                    let g = CGFloat(ptr[offset + 1]) / 255.0
                    let b = CGFloat(ptr[offset + 2]) / 255.0
                    
                    if r > Thresholds.whiteTextBrightness &&
                       g > Thresholds.whiteTextBrightness &&
                       b > Thresholds.whiteTextBrightness {
                        brightPixels += 1
                    }
                    monitoredPixels += 1
                }
            }
        }
        
        let whiteRatio = monitoredPixels > 0 ? Double(brightPixels) / Double(monitoredPixels) : 0
        return whiteRatio > 0.005 
    }
    
    /// Helper per convertire RGB in HSV.
    private static func rgbToHsv(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        let minV = min(r, min(g, b))
        let maxV = max(r, max(g, b))
        let delta = maxV - minV
        
        var h: CGFloat = 0
        if delta != 0 {
            if maxV == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxV == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
        }
        
        let s = (maxV == 0 ? 0 : delta / maxV)
        let v = maxV
        
        return (h, s, v)
    }
}
