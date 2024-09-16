//
//  QRCodeScannerView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-15.
//
#if os(iOS)
import SwiftUI

import CodeScanner
import AVFoundation

struct QRCodeScannerView: View {
    @Binding var showScanner: Bool
    let handleScan: (Result<ScanResult, ScanError>) -> Void
    
    @State var isGalleryPresented = false
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            view
        }
    }
    
    var topBar: some View {
        HStack {
            NavigationBackSheetButton(showSheet: $showScanner)
            Spacer()
            title
            Spacer()
            NavigationBackSheetButton(showSheet: $showScanner)
                .opacity(0)
                .disabled(true)
        }
        .frame(height: 60)
        .padding(.horizontal, 16)
        .background(Color.blue800)
    }
    
    var title: some View {
        Text(NSLocalizedString("scan", comment: "Scan QR Code"))
            .font(.body)
            .bold()
            .foregroundColor(.neutral0)
    }
    
    var view: some View {
        ZStack {
            codeScanner
            outline
                .allowsHitTesting(false)
        }
    }
    
    var outline: some View {
        Image("QRScannerOutline")
            .offset(y: -50)
    }
    
    var codeScanner: some View {
        ZStack(alignment: .bottom) {
            CodeScannerView(
                codeTypes: [.qr],
                isGalleryPresented: $isGalleryPresented,
                videoCaptureDevice: AVCaptureDevice.zoomedCameraForQRCode(withMinimumCodeSize: 100),
                completion: handleScan
            )
            galleryButton
        }
    }
    
    var galleryButton: some View {
        Button {
            isGalleryPresented.toggle()
        } label: {
            OpenButton(buttonIcon: "photo.stack", buttonLabel: "uploadFromGallery")
        }
        .padding(.bottom, 50)
    }
}
#endif
