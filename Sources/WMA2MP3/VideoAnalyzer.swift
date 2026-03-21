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
        // Saturazione bassa per includere anche i blu più desaturati/scuri
        static let minSaturation: CGFloat = 0.15
        // Value bassa per includere i blu molto scuri (navy/notte)
        static let minValue: CGFloat = 0.10
        
        // Soglia al 25%: la schermata ha elementi decorativi non-blu (logo, cerchi)
        static let bluePixelPercentage: Double = 0.25
        
        // Luminosità minima per il testo bianco centrale (scesa a 0.55 perché col downscaling
        // il testo sottile sfuma col blu diventando grigio chiaro invece che bianco)
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
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue // garantisce RGBA
        ) else { return nil }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixelData, width, height, bytesPerRow)
    }

    /// Analizza un'immagine per determinare se è una schermata blu di delimitazione.
    static func isBlueScreen(_ image: CGImage) -> Bool {
        guard let (pixels, width, height, bytesPerRow) = normalizeToRGBA(image) else {
            return false
        }
        
        var bluePixels = 0
        let step = 4
        var sampledTotal = 0
        
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4
                // Formato garantito RGBA: offset=R, +1=G, +2=B, +3=A
                let r = CGFloat(pixels[offset])     / 255.0
                let g = CGFloat(pixels[offset + 1]) / 255.0
                let b = CGFloat(pixels[offset + 2]) / 255.0
                
                let hsv = rgbToHsv(r: r, g: g, b: b)
                
                if hsv.h >= Thresholds.minHue && hsv.h <= Thresholds.maxHue &&
                   hsv.s >= Thresholds.minSaturation && hsv.v >= Thresholds.minValue {
                    bluePixels += 1
                }
                sampledTotal += 1
            }
        }
        
        let blueRatio = Double(bluePixels) / Double(sampledTotal)
        
        if blueRatio > Thresholds.bluePixelPercentage {
            let hasText = hasCenterWhiteText(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
            if hasText {
                print("DEBUG: Schermata blu rilevata! BlueRatio: \(String(format: "%.2f", blueRatio))")
                return true
            } else {
                print("DEBUG: BlueRatio \(String(format: "%.2f", blueRatio)) > soglia, ma testo non rilevato.")
            }
        }
        
        return false
    }
    
    /// Verifica se c'è una regione luminosa (testo bianco) nel centro dell'immagine.
    private static func hasCenterWhiteText(pixels: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> Bool {
        // Rettangolo centrale: testo "INFO DAY KREATIVEU" è nel terzo sinistro-centrale
        let cxStart = Int(Double(width) * 0.1)
        let cxEnd   = Int(Double(width) * 0.8)
        let cyStart = Int(Double(height) * 0.30)
        let cyEnd   = Int(Double(height) * 0.70)
        
        var brightPixels = 0
        var monitoredPixels = 0
        
        for y in stride(from: cyStart, to: cyEnd, by: 3) {
            for x in stride(from: cxStart, to: cxEnd, by: 3) {
                let offset = y * bytesPerRow + x * 4
                let r = CGFloat(pixels[offset])     / 255.0
                let g = CGFloat(pixels[offset + 1]) / 255.0
                let b = CGFloat(pixels[offset + 2]) / 255.0
                
                if r > Thresholds.whiteTextBrightness &&
                   g > Thresholds.whiteTextBrightness &&
                   b > Thresholds.whiteTextBrightness {
                    brightPixels += 1
                }
                monitoredPixels += 1
            }
        }
        
        let whiteRatio = Double(brightPixels) / Double(monitoredPixels)
        print("DEBUG: WhiteRatio nel centro = \(String(format: "%.4f", whiteRatio))")
        return whiteRatio > 0.005 // 0.5% di pixels chiari nel centro è sufficiente perché il font è sottile
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
