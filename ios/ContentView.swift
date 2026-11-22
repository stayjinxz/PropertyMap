import SwiftUI
import MapKit

struct ContentView: View {
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 39.8, longitude: -98.6), span: .init(latitudeDelta: 42, longitudeDelta: 62)))
    @State private var region = MKCoordinateRegion(center: .init(latitude: 39.8, longitude: -98.6), span: .init(latitudeDelta: 42, longitudeDelta: 62))
    @State private var properties: [Property] = []
    @State private var selected: Property?
    @State private var mode = "both"
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var showSearch = false
    @State private var savedIDs = Set<String>()
    @State private var showSavedOnly = false

    var visible: [Property] { showSavedOnly ? properties.filter { savedIDs.contains($0.id) } : properties }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera, selection: $selected) {
                ForEach(visible) { property in
                    Annotation(property.formattedPrice, coordinate: property.coordinate) {
                        Text(property.price == nil ? "—" : property.formattedPrice)
                            .font(.caption.bold()).padding(.horizontal, 9).padding(.vertical, 7)
                            .background(property.status == "Active" ? Color.blue : Color(.systemBackground))
                            .foregroundStyle(property.status == "Active" ? .white : .primary)
                            .clipShape(Capsule()).shadow(radius: 3)
                    }.tag(property)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onMapCameraChange(frequency: .onEnd) { context in region = context.region }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "house.fill").foregroundStyle(.blue)
                    Text("PropertyMap").font(.title3.bold())
                    Spacer()
                    Button { showSavedOnly.toggle() } label: {
                        Image(systemName: showSavedOnly ? "bookmark.fill" : "bookmark")
                    }.accessibilityLabel("Toggle saved properties")
                    Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("Search address")
                }
                .padding(14).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 16))

                Picker("Properties", selection: $mode) {
                    Text("All").tag("both")
                    Text("For sale").tag("listed")
                    Text("Off market").tag("offmarket")
                }.pickerStyle(.segmented).padding(8).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
                    .onChange(of: mode) { _, _ in Task { await load() } }

                Spacer()
                if let error { Text(error).font(.caption).padding(10).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 10)) }
                Button { Task { await load() } } label: {
                    HStack { if loading { ProgressView() }; Image(systemName: "arrow.clockwise"); Text("Search this area") }
                        .font(.subheadline.bold()).padding(14).background(.blue).foregroundStyle(.white).clipShape(Capsule())
                }.disabled(loading)
            }.padding()
        }
        .sheet(item: $selected) { property in
            PropertyDetailView(property: property, saved: savedIDs.contains(property.id)) {
                if !savedIDs.insert(property.id).inserted { savedIDs.remove(property.id) }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSearch) {
            NavigationStack {
                VStack {
                    TextField("City or street address", text: $query).textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words).onSubmit { Task { await search() } }
                    Button("Search") { Task { await search() } }
                    List(searchResults, id: \.self) { item in
                        Button(item.name ?? item.placemark.title ?? "Location") {
                            if let location = item.placemark.location {
                                camera = .region(.init(center: location.coordinate, span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                                region = .init(center: location.coordinate, span: .init(latitudeDelta: 0.05, longitudeDelta: 0.05))
                                showSearch = false
                                Task { await load() }
                            }
                        }
                    }
                }.padding().navigationTitle("Find a place").toolbar { Button("Done") { showSearch = false } }
            }
        }
    }

    private func search() async {
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
        do { searchResults = try await MKLocalSearch(request: request).start().mapItems }
        catch { self.error = "Address search unavailable: \(error.localizedDescription)" }
    }

    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            // Limit the query radius and avoid nationwide requests while zoomed out.
            guard region.span.latitudeDelta < 3 else { error = "Zoom into a neighborhood, then search this area."; return }
            let radius = min(25, max(0.5, region.span.latitudeDelta * 35))
            properties = try await PropertyAPI.nearby(latitude: region.center.latitude, longitude: region.center.longitude, radius: radius, mode: mode)
            if properties.isEmpty { error = "No available property records in this area." }
        } catch { self.error = "Could not load properties. Check the backend connection." }
    }
}

struct PropertyDetailView: View {
    let property: Property
    let saved: Bool
    let toggleSaved: () -> Void
    @State private var estimate: EstimateResponse?
    @State private var fetching = false
    @State private var estimateError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Capsule().fill(.gray.opacity(0.4)).frame(width: 35, height: 5).frame(maxWidth: .infinity)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(property.formattedPrice).font(.largeTitle.bold())
                        Text(property.priceType).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: toggleSaved) { Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.title2) }
                }
                Text(property.address).font(.headline)
                Text(property.status == "Active" ? "Listed for sale" : "Off-market property").foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    if let beds = property.bedrooms { Label("\(beds.formatted()) beds", systemImage: "bed.double") }
                    if let baths = property.bathrooms { Label("\(baths.formatted()) baths", systemImage: "drop") }
                    if let sqft = property.squareFootage { Label("\(Int(sqft)) sqft", systemImage: "square.dashed") }
                }.font(.caption)
                if let last = property.lastSalePrice {
                    Text("Last sale: \(last.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                    if let date = property.lastSaleDate { Text("Sale date: \(date.prefix(10))").font(.caption).foregroundStyle(.secondary) }
                }
                Divider()
                Button { Task { await fetchEstimate() } } label: {
                    HStack { if fetching { ProgressView() }; Text("Get estimated market value") }
                }.disabled(fetching)
                if let estimate {
                    Text(estimate.price.map { $0.formatted(.currency(code: "USD").precision(.fractionLength(0))) } ?? "Estimate unavailable")
                        .font(.title2.bold())
                    if let low = estimate.priceRangeLow, let high = estimate.priceRangeHigh {
                        Text("Estimated range: \(low.formatted(.currency(code: "USD").precision(.fractionLength(0)))) – \(high.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                    }
                }
                if let estimateError { Text(estimateError).foregroundStyle(.red).font(.caption) }
                Text("Listing prices, tax assessments, last sale prices and automated estimates are not interchangeable. Estimates are not appraisals. Coverage and freshness vary by location.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(22)
        }
    }

    private func fetchEstimate() async {
        fetching = true; defer { fetching = false }
        do { estimate = try await PropertyAPI.estimate(address: property.address) }
        catch { estimateError = "Estimate currently unavailable." }
    }
}
