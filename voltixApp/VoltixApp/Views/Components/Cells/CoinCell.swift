//
//  CoinCell.swift
//  VoltixApp
//
//  Created by Amol Kumar on 2024-03-08.
//

import SwiftUI

struct CoinCell: View {
    let coin: Coin
    let group: GroupedChain
    let vault: Vault
    
    @StateObject var coinViewModel = CoinViewModel()
	
    var body: some View {
        HStack(spacing: 12) {
            logo
            content
        }
        .padding(16)
        .background(Color.blue600)
        .onAppear {
            Task {
                await setData()
            }
        }
    }
    
    var logo: some View {
        Image(coin.logo)
            .resizable()
            .frame(width: 32, height: 32)
            .cornerRadius(50)
    }
    
    var content: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            amount
        }
    }
    
    var header: some View {
        HStack {
            title
            Spacer()
            quantity
        }
    }
    
    var title: some View {
        Text(coin.ticker)
            .font(.body20Menlo)
            .foregroundColor(.neutral0)
    }
    
    var quantity: some View {
        let balanceString = coinViewModel.coinBalance
        
        return Text(balanceString ?? "1000")
            .font(.body16Menlo)
            .foregroundColor(.neutral0)
            .redacted(reason: balanceString==nil ? .placeholder : [])
    }
    
    var amount: some View {
        let balanceInFiat = coinViewModel.balanceFiat
        
        return Text(balanceInFiat ?? "1000")
            .font(.body16MenloBold)
            .foregroundColor(.neutral0)
            .redacted(reason: balanceInFiat==nil ? .placeholder : [])
    }
    
    private func setData() async {
        await coinViewModel.loadData(coin: coin)
    }
}

#Preview {
    CoinCell(coin: Coin.example, group: GroupedChain.example, vault: Vault.example)
}
