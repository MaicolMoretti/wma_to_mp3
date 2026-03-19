# Convertitore da WMA a MP3

Un'applicazione desktop nativa per macOS, pronta all'uso, per convertire file Windows Media Audio (.wma) in formato MP3 utilizzando un binario statico `ffmpeg` integrato. Sviluppata con SwiftUI e Swift Package Manager per macOS 14+.

## Caratteristiche
- **Dashboard Intuitiva**: Scegli facilmente tra conversione audio o editing video all'avvio.
- **Convertitore WMA to MP3**: Trascina i file `.wma` direttamente nella finestra dell'app per una conversione batch ultra-veloce.
- **Editor Video (Novità)**: Funzionalità di editing video integrata (in continuo sviluppo).
- **Elaborazione Batch**: Converti più file contemporaneamente.
- **Background Conversion**: L'interfaccia rimane fluida e non si blocca mai durante la conversione.
- **Controllo della Qualità**: Qualità di output personalizzabili (128, 192, 256, 320 kbps).
- **Metadati**: Preserva automaticamente i tag ID3.

## Requisiti
- macOS 14.0 o successivo (Sonoma+)
- Xcode Command Line Tools o Xcode

## Istruzioni per la Compilazione
Questo progetto utilizza Swift Package Manager combinato con un `Makefile` leggero per compilare rapidamente un pacchetto `.app` strutturato.

1. Apri il terminale nella directory del progetto.
2. Esegui `make`.
   ```bash
   make
   ```
   *Il Makefile scaricherà automaticamente una build statica di `ffmpeg` per macOS compatibile con LGPL, compilerà l'eseguibile Swift, incorporerà le Risorse necessarie e pacchettizzerà `WMA2MP3.app`.*

3. Esegui l'applicazione:
   ```bash
   make run
   ```

## Sviluppo e Test
Per eseguire la suite di test automatizzati XCTest che copre la logica di deduplicazione e le operazioni sui file:

```bash
make test
```

## Architettura
- **SwiftUI + Observation Framework** (`@Observable`): Gestisce il frontend reattivo, separando nettamente la logica dalla gerarchia delle viste.
- **ConversionManager**: Un attore/coordinatore di TaskGroup che orchestra i task di `FFmpegEngine` per massimizzare la velocità di conversione attraverso la parallelizzazione multi-core.
- **FFmpegEngine**: Livello di esecuzione in sandbox che avvolge `Foundation.Process`, leggendo e analizzando automaticamente lo `stderr` per barre di progressione reattive.
