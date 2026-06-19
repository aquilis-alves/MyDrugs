import SwiftUI

// 1. Criamos um Enum para ligar os dados aos teus ficheiros reais
enum AbaDoApp: String, CaseIterable, Identifiable {
    case home
    case maps
    case search
    case preorder
    
    // O ID obrigatório para o ForEach funcionar
    var id: String { self.rawValue }
    
    // Define o ícone SF Symbol para cada aba
    var icone: String {
        switch self {
        case .home: return "house"
        case .maps: return "map"
        case .search: return "magnifyingglass"
        case .preorder: return "bag"
        }
    }
    
    // Define o título de texto que aparece por baixo do ícone
    var titulo: String {
        switch self {
        case .home: return "Home"
        case .maps: return "Mapas"
        case .search: return "Procurar"
        case .preorder: return "Reserva"
        }
    }
    
    // 2. O SEGREDO: Esta função instancia e devolve a View correta baseada no caso
    @ViewBuilder
    func carregarView() -> some View {
        switch self {
        case .home:
            HomeView() // Carrega o teu ficheiro HomeView
        case .maps:
            MapsView() // Carrega o teu ficheiro MapsView
        case .search:
            SearchView() // Carrega o teu ficheiro SearchView
        case .preorder:
            PreOrder()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            // 3. O ForEach percorre automaticamente todos os casos do Enum
            ForEach(AbaDoApp.allCases) { aba in
                Tab(aba.titulo, systemImage: aba.icone) {
                    // 4. Injeta a View correspondente de cada ficheiro
                    aba.carregarView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
