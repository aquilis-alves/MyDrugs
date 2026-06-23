import SwiftUI
import Combine
import MapKit
import CoreLocation
import CoreLocationUI

// MARK: - Modo de Transporte

enum ModoTransporte: String, CaseIterable {
    case carro = "Carro"
    case ape = "A pé"

    var transportType: MKDirectionsTransportType {
        switch self {
        case .carro: return .automobile
        case .ape:   return .walking
        }
    }

    var icone: String {
        switch self {
        case .carro: return "car.fill"
        case .ape:   return "figure.walk"
        }
    }

    var cor: Color {
        switch self {
        case .carro: return .blue
        case .ape:   return .green
        }
    }
}

// MARK: - Model

struct Farmacia: Identifiable {
    let id: String
    let nome: String
    let endereco: String
    let telefone: String
    let coordenadas: CLLocationCoordinate2D
    var distancia: Double? = nil
}

// MARK: - Data

var farmaciasDisponiveis: [Farmacia] = [
    Farmacia(
        id: "14e59c151f41dd4422fc8c585c73cb6d",
        nome: "Farmácia Teresina Zona Sul",
        endereco: "Avenida Higino Cunha, Ilhotas, Teresina - PI",
        telefone: "86-3222-1111",
        coordenadas: CLLocationCoordinate2D(latitude: -5.1052, longitude: -42.7945)
    ),
    Farmacia(
        id: "7a01989ba4d78247326783cff0686120",
        nome: "Farmácia Teresina Centro",
        endereco: "Rua Coelho de Resende, Centro, Teresina - PI",
        telefone: "86-9999-9999",
        coordenadas: CLLocationCoordinate2D(latitude: -5.0500, longitude: -42.8000)
    ),
    Farmacia(
        id: "farmacia-proxima-01",
        nome: "Farmácia Próxima 1",
        endereco: "Teresina - PI",
        telefone: "",
        coordenadas: CLLocationCoordinate2D(latitude: -5.0690, longitude: -42.7968)
    ),
    Farmacia(
        id: "farmacia-proxima-02",
        nome: "Farmácia Próxima 2",
        endereco: "Teresina - PI",
        telefone: "",
        coordenadas: CLLocationCoordinate2D(latitude: -5.0635, longitude: -42.7922)
    ),
    Farmacia(
        id: "farmacia-proxima-03",
        nome: "Farmácia Próxima 3",
        endereco: "Teresina - PI",
        telefone: "",
        coordenadas: CLLocationCoordinate2D(latitude: -5.0598, longitude: -42.7985)
    )
]

// MARK: - Distance Helper

private func calculateRoadDistance(
    _ start: CLLocation,
    _ end: CLLocation,
    transportType: MKDirectionsTransportType = .automobile
) async -> Double {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.coordinate))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.coordinate))
    request.transportType = transportType
    let directions = MKDirections(request: request)
    do {
        let response = try await directions.calculate()
        if let fastest = response.routes.first { return fastest.distance }
    } catch {
        return end.distance(from: start) * 1.5
    }
    return end.distance(from: start) * 1.5
}

private func formatDistance(_ meters: Double) -> String {
    Measurement(value: meters, unit: UnitLength.meters)
        .formatted(.measurement(width: .abbreviated, usage: .road))
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var buscandoLocalizacao: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        buscandoLocalizacao = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.location = locations.first?.coordinate
            self.buscandoLocalizacao = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Erro ao buscar localização: \(error.localizedDescription)")
        DispatchQueue.main.async { self.buscandoLocalizacao = false }
    }
}

// MARK: - ViewModel

class MapsViewModel: ObservableObject {
    @Published var farmaciasOrdenadas: [Farmacia] = farmaciasDisponiveis
    @Published var farmaciaSelecionada: Farmacia? = farmaciasDisponiveis.first
    @Published var calculandoDistancias: Bool = false
    @Published var rota: MKRoute? = nil
    @Published var calculandoRota: Bool = false
    @Published var modoTransporte: ModoTransporte = .carro

    func calcularDistancias(da origem: CLLocation) async {
        await MainActor.run { calculandoDistancias = true }
        var atualizadas: [Farmacia] = []
        for farmacia in farmaciasDisponiveis {
            let destino = CLLocation(
                latitude: farmacia.coordenadas.latitude,
                longitude: farmacia.coordenadas.longitude
            )
            let dist = await calculateRoadDistance(origem, destino, transportType: modoTransporte.transportType)
            var f = farmacia
            f.distancia = dist
            atualizadas.append(f)
        }
        let ordenadas = atualizadas.sorted { ($0.distancia ?? .infinity) < ($1.distancia ?? .infinity) }
        await MainActor.run {
            self.farmaciasOrdenadas = ordenadas
            if self.farmaciaSelecionada == nil { self.farmaciaSelecionada = ordenadas.first }
            self.calculandoDistancias = false
        }
    }

    func calcularRota(da origem: CLLocationCoordinate2D, ate farmacia: Farmacia) async {
        await MainActor.run { calculandoRota = true; rota = nil }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origem))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: farmacia.coordenadas))
        request.transportType = modoTransporte.transportType
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            await MainActor.run { self.rota = response.routes.first; self.calculandoRota = false }
        } catch {
            print("Erro ao calcular rota: \(error.localizedDescription)")
            await MainActor.run { calculandoRota = false }
        }
    }

    func limparRota() { rota = nil }
}

// MARK: - Triangle Shape

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Annotation de Farmácia

struct FarmaciaAnnotationView: View {
    let farmacia: Farmacia
    let selecionada: Bool
    let localizacaoDisponivel: Bool
    let calculandoRota: Bool
    let onTap: () -> Void

    @State private var pulsar = false

    private var cor: Color {
        guard localizacaoDisponivel else { return .gray }
        return selecionada ? .orange : .green
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack {
                    // Anel de ripple para a farmácia selecionada
                    if selecionada && localizacaoDisponivel {
                        Circle()
                            .stroke(cor.opacity(0.5), lineWidth: 2.5)
                            .frame(width: 54, height: 54)
                            .scaleEffect(pulsar ? 1.0 : 0.55)
                            .opacity(pulsar ? 0.0 : 0.75)
                            .animation(
                                .easeOut(duration: 1.3).repeatForever(autoreverses: false),
                                value: pulsar
                            )
                    }

                    // Círculo principal
                    Circle()
                        .fill(cor)
                        .frame(width: 36, height: 36)
                        .shadow(color: cor.opacity(0.5), radius: 5, x: 0, y: 2)

                    // Ícone interno: spinner enquanto calcula, cruz normalmente
                    if calculandoRota && selecionada {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.65)
                    } else {
                        Image(systemName: localizacaoDisponivel ? "cross.fill" : "cross.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .bold))
                    }

                    // Badge de localização bloqueada
                    if !localizacaoDisponivel {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(2.5)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .offset(x: 14, y: -14)
                    }
                }

                // Triângulo — ponta aponta para a coordenada no mapa
                TriangleShape()
                    .fill(cor)
                    .frame(width: 12, height: 7)
            }
        }
        .buttonStyle(.plain)
        .disabled(!localizacaoDisponivel)
        .opacity(localizacaoDisponivel ? 1.0 : 0.4)
        .scaleEffect(selecionada ? 1.15 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: selecionada)
        .onAppear {
            if selecionada && localizacaoDisponivel { pulsar = true }
        }
        .onChange(of: selecionada) { _, newValue in
            pulsar = newValue && localizacaoDisponivel
        }
    }
}

// MARK: - Annotation de Localização do Usuário

struct UsuarioAnnotationView: View {
    @State private var pulsar = false

    var body: some View {
        ZStack {
            // Halo de precisão — comunica que é uma posição aproximada,
            // não um ponto exato (igual ao círculo azul do Maps/Google Maps)
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 70, height: 70)

            Circle()
                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                .frame(width: 46, height: 46)
                .scaleEffect(pulsar ? 1.15 : 0.75)
                .opacity(pulsar ? 0.0 : 0.8)
                .animation(
                    .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                    value: pulsar
                )

            // Ponto central — sua posição
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)

            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
        }
        .onAppear { pulsar = true }
    }
}

// MARK: - Picker de Modo de Transporte

struct ModoTransportePicker: View {
    @Binding var modoSelecionado: ModoTransporte
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ModoTransporte.allCases, id: \.self) { modo in
                Button {
                    guard modoSelecionado != modo else { return }
                    modoSelecionado = modo
                    onChange()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: modo.icone)
                        Text(modo.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(modoSelecionado == modo ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(modoSelecionado == modo ? modo.cor : Color.clear)
                    )
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Picker de Farmácia

struct FarmaciaMenuPicker: View {
    @ObservedObject var viewModel: MapsViewModel
    let onSelecionar: (Farmacia) -> Void

    var body: some View {
        Menu {
            if viewModel.calculandoDistancias {
                Label("Calculando distâncias...", systemImage: "location.circle")
            } else {
                ForEach(viewModel.farmaciasOrdenadas) { farmacia in
                    Button {
                        // Não seleciona/limpa aqui — delega tudo (seleção,
                        // câmera e cálculo de rota) para o closure do pai,
                        // que é o mesmo caminho usado pelo tap no pin.
                        onSelecionar(farmacia)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(farmacia.nome)
                                if let dist = farmacia.distancia {
                                    Text(formatDistance(dist))
                                }
                            }
                            if viewModel.farmaciaSelecionada?.id == farmacia.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.farmaciaSelecionada?.nome ?? "Selecionar Farmácia")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
        }
    }
}

// MARK: - View Principal

struct MapsView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = MapsViewModel()

    @State private var posicaoCamera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -5.062810, longitude: -42.794766),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    // Extrai lógica do tap numa função para reutilizar entre annotation,
    // picker de farmácia e picker de modo de transporte.
    private func executarCalculoRota(para farmacia: Farmacia, de userLocation: CLLocationCoordinate2D) {
        viewModel.farmaciaSelecionada = farmacia
        viewModel.limparRota()
        withAnimation {
            posicaoCamera = .region(
                MKCoordinateRegion(
                    center: farmacia.coordenadas,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                )
            )
        }
        Task {
            await viewModel.calcularRota(da: userLocation, ate: farmacia)
            if let rota = viewModel.rota {
                withAnimation {
                    posicaoCamera = .rect(rota.polyline.boundingMapRect.insetBy(dx: -2000, dy: -2000))
                }
            }
        }
    }

    // Recalcula a rota para a farmácia já selecionada — usado quando o
    // modo de transporte muda. Se não houver localização ou farmácia
    // selecionada ainda, apenas limpa a rota.
    private func recalcularRotaAtual() {
        guard
            let userLocation = locationManager.location,
            let farmacia = viewModel.farmaciaSelecionada
        else {
            viewModel.limparRota()
            return
        }
        executarCalculoRota(para: farmacia, de: userLocation)
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: Mapa
            Map(position: $posicaoCamera) {
                if let localizacaoExata = locationManager.location {
                    Annotation("Local aproximado", coordinate: localizacaoExata, anchor: .center) {
                        UsuarioAnnotationView()
                    }
                }

                // Annotations clicáveis — substituem os Markers antigos
                ForEach(viewModel.farmaciasOrdenadas) { farmacia in
                    Annotation(farmacia.nome, coordinate: farmacia.coordenadas, anchor: .bottom) {
                        FarmaciaAnnotationView(
                            farmacia: farmacia,
                            selecionada: viewModel.farmaciaSelecionada?.id == farmacia.id,
                            localizacaoDisponivel: locationManager.location != nil,
                            calculandoRota: viewModel.calculandoRota,
                            onTap: {
                                guard let userLocation = locationManager.location else { return }
                                executarCalculoRota(para: farmacia, de: userLocation)
                            }
                        )
                    }
                }

                if let rota = viewModel.rota {
                    MapPolyline(rota.polyline)
                        .stroke(viewModel.modoTransporte.cor, lineWidth: 5)
                }
            }
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()

            // MARK: Picker no topo
            VStack {
                FarmaciaMenuPicker(viewModel: viewModel) { farmacia in
                    withAnimation {
                        posicaoCamera = .region(
                            MKCoordinateRegion(
                                center: farmacia.coordenadas,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                    // Só calcula automaticamente se a localização do
                    // usuário já estiver disponível — senão, a seleção
                    // só centraliza o mapa na farmácia, sem rota.
                    if let userLocation = locationManager.location {
                        executarCalculoRota(para: farmacia, de: userLocation)
                    } else {
                        viewModel.farmaciaSelecionada = farmacia
                        viewModel.limparRota()
                    }
                }
                .padding(.top, 16)
                Spacer()
            }

            // MARK: Controles na parte inferior
            VStack(spacing: 12) {

                if let userLocation = locationManager.location {
                    // --- Localização disponível ---

                    if let rota = viewModel.rota {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rota calculada · \(viewModel.modoTransporte.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 8) {
                                    Label(formatDistance(rota.distance), systemImage: "road.lanes")
                                    Label(formatTravelTime(rota.expectedTravelTime), systemImage: "clock")
                                }
                                .font(.subheadline)
                                .bold()
                            }
                            Spacer()
                            Button { viewModel.limparRota() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground).opacity(0.95))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }

                    ModoTransportePicker(modoSelecionado: $viewModel.modoTransporte) {
                        // Antes só limpava a rota — agora recalcula
                        // automaticamente para a farmácia já selecionada.
                        recalcularRotaAtual()
                    }

                } else if locationManager.buscandoLocalizacao {
                    // --- Buscando localização: loading card ---
                    HStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Buscando sua localização...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Isso pode levar alguns segundos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                } else {
                    // --- Ainda sem localização ---
                    Text("Clique no botão para encontrar sua localização")
                        .font(.subheadline)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.85))
                        .cornerRadius(10)
                        .shadow(radius: 5)

                    LocationButton(.currentLocation) {
                        locationManager.requestLocation()
                    }
                    .symbolVariant(.fill)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .frame(height: 44)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .animation(.easeInOut(duration: 0.28), value: locationManager.buscandoLocalizacao)
            .animation(.easeInOut(duration: 0.28), value: locationManager.location?.latitude)
        }
        .onChange(of: locationManager.location?.latitude) {
            if let coordenada = locationManager.location {
                withAnimation {
                    posicaoCamera = .region(
                        MKCoordinateRegion(
                            center: coordenada,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
                Task {
                    await viewModel.calcularDistancias(
                        da: CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude)
                    )
                }
            }
        }
    }
}

// MARK: - Helpers de formatação

private func formatTravelTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60
    let remaining = minutes % 60
    return remaining > 0 ? "\(hours)h \(remaining)min" : "\(hours)h"
}

#Preview {
    MapsView()
}
