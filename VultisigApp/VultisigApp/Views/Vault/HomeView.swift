//
//  HomeView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-11.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @State var selectedVault: Vault? = nil
    
    @EnvironmentObject var deeplinkViewModel: DeeplinkViewModel
    @EnvironmentObject var viewModel: HomeViewModel
    
    @State var vaults: [Vault] = []
    
    @State var showVaultsList = false
    @State var isEditingVaults = false
    @State var showMenu = false
    @State var didUpdate = true
    @State var shouldJoinKeygen = false
    @State var shouldKeysignTransaction = false
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            Background()
            
            if showMenu {
                SettingsView(showMenu: $showMenu, homeViewModel: viewModel)
            } else {
                view
            }
        }
    }
    
    var view: some View {
        VStack(spacing: 0) {
#if os(macOS)
            navigationContent
#endif
            
            ZStack {
                if let vault = viewModel.selectedVault {
                    VaultDetailView(showVaultsList: $showVaultsList, vault: vault)
                }
                
                VaultsView(viewModel: viewModel, showVaultsList: $showVaultsList, isEditingVaults: $isEditingVaults)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            setData()
        }
        .navigationDestination(isPresented: $shouldJoinKeygen) {
            JoinKeygenView(vault: Vault(name: "Main Vault"))
        }
        .navigationDestination(isPresented: $shouldKeysignTransaction) {
            if let vault = viewModel.selectedVault {
                JoinKeysignView(vault: vault)
            }
        }
        .toolbar {
            ToolbarItem(placement: Placement.topBarLeading.getPlacement()) {
                menuButton
            }
            
#if os(iOS)
            ToolbarItem(placement: Placement.principal.getPlacement()) {
                navigationTitle
            }
#endif
            
            ToolbarItem(placement: Placement.topBarTrailing.getPlacement()) {
                editButton
            }
        }
    }
    
    var navigationTitle: some View {
        ZStack {
            HStack {
                title
                
                if viewModel.selectedVault != nil {
                    Image(systemName: "chevron.up")
                        .font(.body8Menlo)
                        .bold()
                        .foregroundColor(.neutral0)
                        .rotationEffect(.degrees(showVaultsList ? 0 : 180))
                }
            }
        }
        .onTapGesture {
            switchView()
        }
    }
    
    var navigationContent: some View {
        VStack(spacing: 0) {
            navigationTitle
                .padding(.vertical, 12)
            Separator()
        }
    }
    
    var title: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("vaults", comment: "Vaults"))
            Text(viewModel.selectedVault?.name ?? NSLocalizedString("vault", comment: "Home view title"))
        }
        .offset(y: showVaultsList ? 9 : -10)
        .frame(height: 20)
        .clipped()
        .bold()
        .foregroundColor(.neutral0)
#if os(iOS)
        .font(.body)
#elseif os(macOS)
        .font(.title2)
#endif
    }
    
    var menuButton: some View {
        Button {
            showMenu.toggle()
        } label: {
            NavigationMenuButton()
        }
        
    }
    
    var editButton: some View {
        NavigationHomeEditButton(
            vault: viewModel.selectedVault,
            showVaultsList: showVaultsList,
            isEditingVaults: $isEditingVaults
        )
    }
    
    private func setData() {
        fetchVaults()
        shouldJoinKeygen = false
        shouldKeysignTransaction = false
        
        if let vault = selectedVault {
            viewModel.setSelectedVault(vault)
            selectedVault = nil
            return
        } else {
            viewModel.loadSelectedVault(for: vaults)
        }
        
        presetValuesForDeeplink()
    }
    
    private func presetValuesForDeeplink() {
        guard let type = deeplinkViewModel.type else {
            return
        }
        deeplinkViewModel.type = nil
        
        switch type {
        case .NewVault:
            moveToCreateVaultView()
        case .SignTransaction:
            moveToVaultsView()
        case .Unknown:
            return
        }
    }
    
    private func moveToCreateVaultView() {
        showVaultsList = false
        shouldJoinKeygen = true
    }
    
    private func moveToVaultsView() {
        guard let vault = deeplinkViewModel.selectedVault else {
            return
        }
        
        viewModel.setSelectedVault(vault)
        showVaultsList = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldKeysignTransaction = true
        }
    }
    
    private func switchView() {
        guard viewModel.selectedVault != nil else {
            return
        }
        
        withAnimation(.easeInOut) {
            showVaultsList.toggle()
        }
    }
    
    private func fetchVaults() {
        let fetchVaultDescriptor = FetchDescriptor<Vault>()
        do {
            vaults = try modelContext.fetch(fetchVaultDescriptor)
        } catch {
            print(error)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(DeeplinkViewModel())
        .environmentObject(HomeViewModel())
}
