//
//  Created by Alex.M on 09.06.2022.
//

import Foundation
import Combine
import AVKit
import UIKit.UIImage
import PDFKit

@MainActor
final class FullscreenCellViewModel: ObservableObject {

    let mediaModel: MediaModelProtocol

    @Published var image: UIImage? = nil
    @Published var player: AVPlayer? = nil
    @Published var isPlaying = false
    @Published var videoSize: CGSize = .zero
    @Published var pdfDocument: PDFDocument? = nil

    private var currentTask: Task<Void, Never>?

    init(mediaModel: MediaModelProtocol) {
        self.mediaModel = mediaModel
    }

    func onStart() async {
        guard image == nil || player == nil else { return }

        currentTask?.cancel()
        currentTask = Task {
            switch self.mediaModel.mediaType {
            case .image:
                let data = try? await mediaModel.getData() // url is slow to load in UI, this way photos don't flicker when swiping
                guard let data = data else { return }
                DispatchQueue.main.async {
                    self.image = UIImage(data: data)
                }
            case .video:
                let url = await mediaModel.getURL()
                guard let url = url else { return }
                setupPlayer(url)
                videoSize = await getVideoSize(url)
            case .none:
                break
                
            case .pdf:
                let url = await mediaModel.getURL()
                guard let url = url else { return }
                loadPDFDocument(from: url)
            }
        }
    }

    func setupPlayer(_ url: URL) {
        DispatchQueue.main.async {
            self.player = AVPlayer(url: url)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(finishVideo), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    func loadPDFDocument(from url: URL) {
        if let pdfDocument = PDFDocument(url: url) {
            DispatchQueue.main.async {
                self.pdfDocument = pdfDocument
            }
        } else {
            print("Failed to load PDF document.")
        }
    }


    @objc func finishVideo() {
        player?.seek(to: CMTime(seconds: 0, preferredTimescale: 10))
        isPlaying = false
    }

    func onStop() {
        currentTask = nil
        image = nil
        player = nil
        isPlaying = false
    }

    func togglePlay() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying = !isPlaying
    }

    func getVideoSize(_ url: URL) async -> CGSize {
        let videoAsset = AVURLAsset(url : url)

        let videoAssetTrack = try? await videoAsset.loadTracks(withMediaType: .video).first
        let naturalSize = (try? await videoAssetTrack?.load(.naturalSize)) ?? .zero
        let transform = try? await videoAssetTrack?.load(.preferredTransform)
        if (transform?.tx == naturalSize.width && transform?.ty == naturalSize.height) || (transform?.tx == 0 && transform?.ty == 0) {
            return naturalSize
        } else {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        }
    }
}
