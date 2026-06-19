import SwiftUI
import MapKit
import CoreLocation
import CoreLocationUI
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // REGRAS: Removida a linha do 'objectWillChange', o SwiftUI cuida disso!
    
    let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Atualiza a localização na Main Thread para garantir a segurança da UI
        DispatchQueue.main.async {
            self.location = locations.first?.coordinate
        }
    }
    
    // IMPORTANTE: Sempre que usamos 'requestLocation()', este método de erro é OBRIGATÓRIO.
    // Se não colocar, o app pode fechar (crash) ao falhar em buscar o sinal de GPS.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Erro ao buscar localização: \(error.localizedDescription)")
    }
}

struct MapsView: View {
    @StateObject private var locationManager = LocationManager()
    
    // 1. Inicializamos com uma localização padrão (Ex: Brasília/Centro do Brasil)
    // Se o usuário não apertar o botão, o mapa ficará parado aqui.
    @State private var posicaoCamera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -15.793889, longitude: -47.882778),
            span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0) // Zoom mais afastado
        )
    )
    
    var body: some View {
        // 2. Usamos ZStack para colocar o botão flutuando em cima do mapa
        ZStack(alignment: .bottom) {
            
            // CAMADA DE FUNDO: O Mapa
            Map(position: $posicaoCamera) {
                if let localizacaoExata = locationManager.location {
                    Marker("Voce Esta aqui", coordinate: localizacaoExata)
                        .tint(.red)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea() // 3. Faz o mapa preencher a tela inteira!
            
            // CAMADA DA FRENTE: Textos e Botão Flutuantes
            VStack(spacing: 15) {
                if let location = locationManager.location {
                    Text("Sua localização)")
                        .font(.subheadline)
                        .bold()
                        .padding()
                        // Adicionamos um fundo branco transparente para o texto não sumir no mapa
                        .background(Color(.systemBackground).opacity(0.85))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        
                } else {
                    Text("Clique no botão para encontrar sua localização")
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.85))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                
                LocationButton(.currentLocation) {
                    locationManager.requestLocation()
                }
                .symbolVariant(.fill)
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(height: 44)
                .padding(.bottom, 30) // Dá um espaço do fundo da tela
            }
            .padding(.horizontal)
        }
        // Fica escutando a mudança de coordenada para mover a câmera suavemente
        .onChange(of: locationManager.location?.latitude) {
            if let coordenada = locationManager.location {
                withAnimation {
                    posicaoCamera = .region(
                        MKCoordinateRegion(
                            center: coordenada,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )
                    )
                }
            }
        }
    }
}
#Preview {
    MapsView()
}
