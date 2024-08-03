//
//  PeerDiscoveryView.swift
//  VultisigApp
//

import OSLog
import SwiftUI

struct PeerDiscoveryView: View {
    let tssType: TssType
    let vault: Vault
    let selectedTab: SetupVaultState
    
    @StateObject var viewModel = KeygenPeerDiscoveryViewModel()
    @StateObject var participantDiscovery = ParticipantDiscovery(isKeygen: true)
    @StateObject var shareSheetViewModel = ShareSheetViewModel()
    
    @State var qrCodeImage: Image? = nil
    @State var isLandscape: Bool = true
    @State var isPhoneSE = false
    
    @State private var showInvalidNumberOfSelectedDevices = false
    
    @Environment(\.displayScale) var displayScale
    
#if os(iOS)
    @State private var orientation = UIDevice.current.orientation
    private var idiom : UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }
#endif
    
    let columns = [
        GridItem(.adaptive(minimum: 160)),
        GridItem(.adaptive(minimum: 160)),
        GridItem(.adaptive(minimum: 160)),
    ]
    
    let logger = Logger(subsystem: "peers-discory", category: "communication")
    
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Background()
                    .onAppear {
                        setData(proxy)
                    }
            }
            
            states
        }
        .navigationTitle(getTitle())
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.startDiscovery()
        }
        .onAppear {
            viewModel.setData(vault: vault, tssType: tssType, participantDiscovery: participantDiscovery)
            setData()
        }
        .onDisappear {
            viewModel.stopMediator()
        }
        
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .detectOrientation($orientation)
        .onChange(of: orientation) { oldValue, newValue in
            setData()
        }
#endif
        .toolbar {
            ToolbarItem(placement: Placement.topBarLeading.getPlacement()) {
                NavigationBackButton()
            }
            // only show the QR share button when it is in peer discovery
            if viewModel.status == .WaitingForDevices {
                ToolbarItem(placement: Placement.topBarTrailing.getPlacement()) {
                    NavigationQRShareButton(title: "joinKeygen", renderedImage: shareSheetViewModel.renderedImage)
                }
            }
        }
        
        
    }
    
    var states: some View {
        VStack {
            switch viewModel.status {
            case .WaitingForDevices:
                waitingForDevices
            case .Summary:
                summary
            case .Keygen:
                keygenView
            case .Failure:
                failureText
            }
        }
        .foregroundColor(.neutral0)
    }
    
    var waitingForDevices: some View {
        VStack(spacing: 0) {
            content
            bottomButton
        }
    }
    
    var summary: some View {
        KeyGenSummaryView(viewModel: viewModel)
    }
    
    var content: some View {
        ZStack {
            if isLandscape {
                landscapeContent
            } else {
                portraitContent
            }
        }
    }
    
    var landscapeContent: some View {
        HStack {
            qrCode
            
#if os(iOS)
            VStack {
                list
                    .padding(20)
                vaultDetail
            }
#elseif os(macOS)
            VStack {
                vaultDetail
                list
            }
            .padding(40)
#endif
        }
    }
    
    var portraitContent: some View {
        VStack(spacing: 0) {
            vaultDetail
            qrCode
            list
        }
    }
    
    var qrCode: some View {
        paringBarcode
    }
    
    var list: some View {
        VStack(spacing: isPhoneSE ? 4 : 12) {
            networkPrompts
            deviceContent
            instructions
        }
    }
    
    var deviceContent: some View {
        ZStack {
            if participantDiscovery.peersFound.count == 0 {
                lookingForDevices
            } else {
                deviceList
            }
        }
    }
    
    var lookingForDevices: some View {
        LookingForDevicesLoader()
    }
    
    var paringBarcode: some View {
        VStack {
            Text(NSLocalizedString("pairWithOtherDevices", comment: "Pair with two other devices"))
                .font(.body18MenloBold)
                .multilineTextAlignment(.center)
            
            qrCodeImage?
                .resizable()
#if os(iOS)
                .background(Color.blue600)
                .frame(maxWidth: isPhoneSE ? 250 : nil)
                .frame(maxHeight: isPhoneSE ? 250 : nil)
                .aspectRatio(
                    contentMode:
                        participantDiscovery.peersFound.count == 0 && idiom == .phone ?
                        .fill :
                            .fit
                )
                .padding()
                .frame(maxHeight: .infinity)
#elseif os(macOS)
                .background(Color.blue600)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: .infinity)
                .padding(24)
#endif
                .cornerRadius(20)
                .overlay (
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.turquoise600, style: StrokeStyle(lineWidth: 2, dash: [12]))
                        .aspectRatio(contentMode: .fit)
                )
                .padding(1)
        }
        .cornerRadius(10)
        .shadow(radius: 5)
#if os(iOS)
        .padding(isPhoneSE ? 8 : 20)
#elseif os(macOS)
        .padding(40)
#endif
    }
    
    var deviceList: some View {
        ZStack {
            if isLandscape {
                gridList
            } else {
                scrollList
            }
        }
    }
    
    var scrollList: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                devices
            }
            .padding(.horizontal, 30)
        }
#if os(iOS)
        .padding(idiom == .phone ? 0 : 20)
#elseif os(macOS)
        .padding(20)
#endif
    }
    
    var gridList: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                devices
            }
#if os(iOS)
            .padding(idiom == .phone ? 0 : 20)
#endif
        }
        .scrollIndicators(.hidden)
    }
    
    var networkPrompts: some View {
        NetworkPrompts(selectedNetwork: $viewModel.selectedNetwork)
            .onChange(of: viewModel.selectedNetwork) {
                viewModel.restartParticipantDiscovery()
            }
#if os(iOS)
            .padding(.top, idiom == .pad ? 10 : 0)
#elseif os(macOS)
            .padding(.top, 10)
#endif
    }
    
    var devices: some View {
        ForEach(participantDiscovery.peersFound, id: \.self) { peer in
            Button {
                handleSelection(peer)
            } label: {
                PeerCell(id: peer, isSelected: viewModel.selections.contains(peer))
            }
            .onAppear {
                handleAutoSelection()
            }
        }
#if os(iOS)
        .padding(idiom == .phone ? 0 : 8)
#endif
    }
    
    var instructions: some View {
        InstructionPrompt(networkType: viewModel.selectedNetwork)
            .padding(.vertical, isPhoneSE ? 0 : 10)
    }
    
    func disableContinueButton() -> Bool {
        switch selectedTab {
        case .TwoOfTwoVaults:
            return viewModel.selections.count < 2
        case .TwoOfThreeVaults:
            return viewModel.selections.count < 3
        case .MOfNVaults:
            return viewModel.selections.count < 2
        }
    }
    
    var bottomButton: some View {
        Button(action: {
            viewModel.showSummary()
        }) {
            FilledButton(title: "continue")
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .disabled(disableContinueButton())
        .opacity(disableContinueButton() ? 0.8 : 1)
        .grayscale(disableContinueButton() ? 1 : 0)
#if os(macOS)
        .padding(.bottom, 30)
#endif
    }
    
    var keygenView: some View {
        KeygenView(
            vault: viewModel.vault,
            tssType: tssType,
            keygenCommittee: viewModel.selections.map { $0 },
            vaultOldCommittee: viewModel.vault.signers.filter { viewModel.selections.contains($0)},
            mediatorURL: viewModel.serverAddr,
            sessionID: viewModel.sessionID,
            encryptionKeyHex: viewModel.encryptionKeyHex ?? "",
            oldResharePrefix: viewModel.vault.resharePrefix ?? ""
        )
    }
    
    var failureText: some View {
        VStack{
            Text(self.viewModel.errorMessage)
                .font(.body15MenloBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
        }
    }
    
    var vaultDetail: some View {
        Text(viewModel.vaultDetail)
            .font(.body15MenloBold)
            .multilineTextAlignment(.center)
    }
    
    private func setData() {
#if os(iOS)
        isLandscape = (orientation == .landscapeLeft || orientation == .landscapeRight) && idiom == .pad
#endif
        
        qrCodeImage = viewModel.getQrImage(size: 100)
        
        guard let qrCodeImage else {
            return
        }
        
        shareSheetViewModel.render(
            title: "joinKeygen",
            qrCodeImage: qrCodeImage,
            displayScale: displayScale
        )
    }
    
    private func handleSelection(_ peer: String) {
        if viewModel.selections.contains(peer) {
            if peer != viewModel.localPartyID {
                viewModel.selections.remove(peer)
            }
        } else {
            viewModel.selections.insert(peer)
        }
        setNumberOfPairedDevices();
    }
    
    private func handleAutoSelection() {
        guard tssType == .Keygen else {
            return
        }
        
        if selectedTab == .TwoOfTwoVaults {
            if participantDiscovery.peersFound.count == 1 {
                handleSelection(participantDiscovery.peersFound[0])
                viewModel.showSummary()
            }
        } else if selectedTab == .TwoOfThreeVaults {
            if participantDiscovery.peersFound.count == 1 {
                handleSelection(participantDiscovery.peersFound[0])
            } else if participantDiscovery.peersFound.count == 2 {
                handleSelection(participantDiscovery.peersFound[1])
                viewModel.showSummary()
            }
        }
    }
    
    private func getTitle() -> String {
        NSLocalizedString("keygenFor", comment: "") +
        " " +
        selectedTab.getNavigationTitle() +
        " " +
        NSLocalizedString("vault", comment: "")
    }
    
    func setNumberOfPairedDevices() {
        
        let totalSigners = viewModel.selections.count
        
        switch selectedTab {
        case .TwoOfTwoVaults:
            viewModel.vaultDetail = String(format:  NSLocalizedString("numberOfPairedDevicesTwoOfTwo", comment: ""), totalSigners)
        case .TwoOfThreeVaults:
            viewModel.vaultDetail = String(format:  NSLocalizedString("numberOfPairedDevicesTwoOfThree", comment: ""), totalSigners)
        default:
            viewModel.vaultDetail = String(format:  NSLocalizedString("numberOfPairedDevicesMOfN", comment: ""), totalSigners)
        }
        
    }
    
    private func setData(_ proxy: GeometryProxy) {
        let screenWidth = proxy.size.width
        
        if screenWidth<380 {
            isPhoneSE = true
        }
    }
}

#Preview {
    PeerDiscoveryView(tssType: .Keygen, vault: Vault.example, selectedTab: .TwoOfTwoVaults)
        .frame(minWidth: 900, minHeight: 600)
}
