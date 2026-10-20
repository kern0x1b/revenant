import SwiftUI

struct Product: Identifiable, Hashable {
    let id: Int
    let name: String
    let price: Double
    let color: Color
    var rating = 4
}

struct ProductCard: View {
    let product: Product
    let onAdd: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10).fill(product.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.white.opacity(0.8)))
            Text(product.name).font(.subheadline).lineLimit(2)
            HStack(spacing: 2) {
                ForEach(0..<5) { index in Image(systemName: index < product.rating ? "star.fill" : "star").font(.caption2).foregroundColor(.orange) }
            }
            HStack {
                Text(String(format: "$%.2f", product.price)).font(.headline)
                Spacer()
                Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title2) }
            }
        }
    }
}

struct StoreView: View {
    @State private var products = (1...8).map { Product(id: $0, name: "Product \($0) with a longer name", price: Double($0) * 9.99, color: Color(hue: Double($0) / 9, saturation: 0.5, brightness: 0.85)) }
    @State private var cart: [Product] = []
    @State private var sort = 0
    @State private var query = ""
    @State private var showCart = false

    var shown: [Product] {
        let base = query.isEmpty ? products : products.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return sort == 0 ? base : base.sorted { $0.price < $1.price }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                Picker("Sort", selection: $sort) { Text("Featured").tag(0); Text("Price").tag(1) }
                    .pickerStyle(.segmented).padding(.horizontal)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(shown) { product in ProductCard(product: product) { cart.append(product) } }
                }
                .padding()
            }
            .navigationTitle("Store")
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCart = true } label: { Image(systemName: "cart") }
                        .badge(cart.count)
                }
            }
            .sheet(isPresented: $showCart) {
                NavigationView {
                    List {
                        ForEach(cart) { product in
                            HStack { Text(product.name); Spacer(); Text(String(format: "$%.2f", product.price)) }
                        }
                        .onDelete { cart.remove(atOffsets: $0) }
                        Section { HStack { Text("Total").bold(); Spacer(); Text(String(format: "$%.2f", cart.reduce(0) { $0 + $1.price })).bold() } }
                    }
                    .navigationTitle("Cart")
                }
            }
        }
    }
}

struct OnboardingView: View {
    @State private var page = 0
    let pages = [("Welcome", "hand.wave", Color.blue), ("Discover", "magnifyingglass", Color.purple), ("Enjoy", "heart.fill", Color.pink)]
    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 20) {
                        Image(systemName: item.1).font(.system(size: 80)).foregroundColor(item.2)
                        Text(item.0).font(.largeTitle).bold()
                        Text("A short description of this page that wraps onto more than one line.").multilineTextAlignment(.center).foregroundColor(.secondary)
                    }
                    .padding().tag(index)
                }
            }
            .tabViewStyle(.page)
            Button(page == pages.count - 1 ? "Get started" : "Next") { withAnimation { page = min(page + 1, pages.count - 1) } }
                .buttonStyle(.borderedProminent).controlSize(.large).padding()
        }
    }
}

struct PlayerView: View {
    @State private var playing = false
    @State private var position = 0.3
    @State private var volume = 0.7
    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 220, height: 220)
                .overlay(Image(systemName: "music.note").font(.system(size: 70)).foregroundColor(.white))
                .shadow(radius: 8)
            VStack(spacing: 4) { Text("Song title").font(.title2).bold(); Text("Artist name").foregroundColor(.secondary) }
            VStack(spacing: 4) {
                Slider(value: $position)
                HStack { Text("1:12"); Spacer(); Text("-2:40") }.font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 40) {
                Button { } label: { Image(systemName: "backward.fill").font(.title) }
                Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 40)) }
                Button { } label: { Image(systemName: "forward.fill").font(.title) }
            }
            HStack { Image(systemName: "speaker"); Slider(value: $volume); Image(systemName: "speaker.wave.3") }
        }
        .padding()
    }
}
