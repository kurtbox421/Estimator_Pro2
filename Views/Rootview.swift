//
//  Rootview.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//
import SwiftUI
import PhotosUI

// MARK: - Tabs

enum AppTab: String, CaseIterable {
    case estimates = "Estimates"
    case invoices  = "Invoices"
    case clients   = "Clients"
    case settings  = "Settings"
}

// MARK: - Layout helper

private struct AdaptiveLayout {
    let contentWidth: CGFloat
    let horizontalPadding: CGFloat

    init(
        containerSize: CGSize,
        maxContentWidth: CGFloat = 860,
        minPadding: CGFloat = 16,
        minContentWidth: CGFloat = 320
    ) {
        let availableWidth = containerSize.width

        if availableWidth >= maxContentWidth + (minPadding * 2) {
            contentWidth = maxContentWidth
            horizontalPadding = max((availableWidth - maxContentWidth) / 2, minPadding)
        } else {
            let adjustedWidth = max(availableWidth - (minPadding * 2), minContentWidth)
            contentWidth = adjustedWidth
            horizontalPadding = minPadding
        }
    }
}

// MARK: - Root view

struct RootView: View {
    @EnvironmentObject private var jobVM: JobViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var invoiceVM: InvoiceViewModel

    @State private var selectedTab: AppTab = .estimates
    @State private var showingAddJob = false
    @State private var invoiceSheetMode: AddEditInvoiceView.Mode?
    @State private var showingMaterialGenerator = false
    @State private var generatorTargetJob: Job? = nil
    @State private var showingNewClientForm = false

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveLayout(containerSize: geometry.size)

            ZStack {
                LinearGradient(
                    colors: backgroundColors(for: selectedTab),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    headerBar(availableWidth: layout.contentWidth)

                    heroCard
                        .frame(maxWidth: layout.contentWidth, alignment: .center)

                    contentForSelectedTab
                        .frame(maxWidth: layout.contentWidth)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
                .padding(.horizontal, layout.horizontalPadding)
            }
        }
        .sheet(isPresented: $showingAddJob) {
            NavigationView {
                AddEditJobView(mode: .add)
            }
        }
        .sheet(item: $invoiceSheetMode) { mode in
            NavigationView {
                AddEditInvoiceView(mode: mode)
            }
        }
        .sheet(isPresented: $showingMaterialGenerator) {
            MaterialGeneratorView(
                job: generatorTargetJob
            )
        }
        .sheet(isPresented: $showingNewClientForm) {
            NewClientForm { newClient in
                clientVM.add(newClient)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    private func headerBar(availableWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            headerHorizontal
            headerStacked(width: availableWidth)
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 10) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab
                                      ? Color.white.opacity(0.95)
                                      : Color.black.opacity(0.25))
                        )
                        .foregroundColor(selectedTab == tab ? .black : .white)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                switch selectedTab {
                case .estimates:
                    showingAddJob = true
                case .invoices:
                    invoiceSheetMode = .add
                case .clients:
                    showingNewClientForm = true
                case .settings:
                    break
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .padding(8)
                    .background(Color.white.opacity(0.95))
                    .clipShape(Circle())
                    .foregroundColor(.black)
            }

            Button {
                generatorTargetJob = nil
                showingMaterialGenerator = true
            } label: {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.headline)
                    .padding(8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.17, blue: 0.60),
                                Color(red: 0.90, green: 0.30, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
        }
    }

    private var headerHorizontal: some View {
        HStack {
            tabButtons
            Spacer(minLength: 16)
            actionButtons
        }
    }

    private func headerStacked(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                tabButtons
                    .padding(.trailing)
            }

            HStack {
                Spacer()
                actionButtons
            }
        }
        .frame(maxWidth: width)
    }

    // MARK: Hero card

    @ViewBuilder
    private var heroCard: some View {
        switch selectedTab {
        case .estimates:
            HeroCardView(
                title: "Your job library",
                subtitle: "Plan smarter projects",
                bodyText: "Review estimates, refine materials, and build polished proposals with ease."
            )
        case .invoices:
            HeroCardView(
                title: "Ready-to-send invoices",
                subtitle: "Stay on top of billing",
                bodyText: "Review outstanding invoices and share them with clients when it's time to collect payment."
            )
        case .clients:
            HeroCardView(
                title: "Client directory",
                subtitle: "Know your customers",
                bodyText: "Store contact details, view project history, and launch quick follow-ups in a tap."
            )
        case .settings:
            HeroCardView(
                title: "Workspace settings",
                subtitle: "Tune your tools",
                bodyText: "Customize company details, branding, and defaults so every estimate looks professional."
            )
        }
    }

    // MARK: Tab content

    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch selectedTab {
        case .estimates:
            EstimatesTabView()
        case .invoices:
            InvoicesTabView()
        case .clients:
            ClientsTabView()
        case .settings:
            SettingsTabView()
        }
    }

    // MARK: Background

    private func backgroundColors(for tab: AppTab) -> [Color] {
        switch tab {
        case .estimates:
            return [
                Color(red: 0.12, green: 0.20, blue: 0.35),
                Color(red: 0.05, green: 0.35, blue: 0.40)
            ]
        case .invoices:
            return [
                Color(red: 0.40, green: 0.15, blue: 0.12),
                Color(red: 0.20, green: 0.35, blue: 0.24)
            ]
        case .clients:
            return [
                Color(red: 0.08, green: 0.40, blue: 0.50),
                Color(red: 0.16, green: 0.18, blue: 0.40)
            ]
        case .settings:
            return [
                Color(red: 0.22, green: 0.24, blue: 0.28),
                Color(red: 0.05, green: 0.18, blue: 0.25)
            ]
        }
    }
}

// MARK: - Hero card

struct HeroCardView: View {
    let title: String
    let subtitle: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(subtitle)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.85))

            Text(title)
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text(bodyText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Estimates tab

struct EstimatesTabView: View {
    @EnvironmentObject private var vm: JobViewModel
    private let rowInsets = EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24)

    var body: some View {
        List {
            ForEach(vm.jobs) { job in
                NavigationLink {
                    JobDetailView(job: job)
                } label: {
                    EstimateJobCard(job: job)
                }
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            vm.delete(job)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if vm.jobs.isEmpty {
                Text("No estimates yet. Tap the + button to add your first job.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct EstimateJobCard: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Text(job.category)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        Label("Estimate", systemImage: "doc.text.magnifyingglass")
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.blue.opacity(0.35))
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                Button {
                    // reserved for quick actions
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "folder.fill")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(width: 50, height: 50)
                }
            }

            Divider().background(Color.white.opacity(0.2))

            HStack {
                Label(job.total.currencyFormatted, systemImage: "dollarsign.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("Materials: \(job.materials.count)   Tools: 0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.black.opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Invoices tab

struct InvoicesTabView: View {
    @EnvironmentObject private var invoiceVM: InvoiceViewModel
    private let rowInsets = EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24)

    var body: some View {
        List {
            ForEach(invoiceVM.invoices) { invoice in
                NavigationLink {
                    InvoiceDetailView(invoiceVM: invoiceVM, invoice: invoice)
                } label: {
                    InvoiceCard(invoice: invoice)
                }
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            invoiceVM.delete(invoice)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if invoiceVM.invoices.isEmpty {
                Text("No invoices yet. Convert an estimate and it will show up here for easy sharing and tracking.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Clients tab (NEW COMPACT LIST)

// MARK: - Clients tab

struct ClientsTabView: View {
    @EnvironmentObject private var clientVM: ClientViewModel
    @EnvironmentObject private var jobVM: JobViewModel
    private let rowInsets = EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24)

    var body: some View {
        List {
            // one row per client
            ForEach(clientVM.clients.indices, id: \.self) { index in
                let client = clientVM.clients[index]
                let jobCount = jobVM.jobCount(for: client)

                NavigationLink {
                    ClientDetailView(client: $clientVM.clients[index])
                } label: {
                    ClientRowCard(client: client, jobCount: jobCount)
                }
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            let clientToDelete = clientVM.clients[index]
                            clientVM.delete(clientToDelete)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if clientVM.clients.isEmpty {
                Text("Add a client to start building your directory.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}


// MARK: - Invoice card

private struct InvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                Text(invoice.clientName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                if let dueDate = invoice.dueDate {
                    Text("Due \(dueDate, formatter: Formatters.invoiceDueDate)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Divider().background(Color.white.opacity(0.2))

            HStack {
                Label(invoice.status.displayName, systemImage: "paperplane.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(invoice.status.pillColor)
                    .clipShape(Capsule())
                    .foregroundColor(.white)

                Spacer()

                Text(invoice.amount.currencyFormatted)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

extension Invoice.InvoiceStatus {
    var pillColor: Color {
        switch self {
        case .draft:
            return Color.blue.opacity(0.45)
        case .sent:
            return Color.green.opacity(0.45)
        case .overdue:
            return Color.red.opacity(0.55)
        }
    }
}

// MARK: - Client editable card & helpers (DETAIL SCREEN)

private struct ClientRowCard: View {
    let client: Client
    let jobCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ClientAvatar(initials: client.initials)

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name.isEmpty ? "New client" : client.name)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                if !client.company.isEmpty {
                    Text(client.company)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                if !client.address.isEmpty {
                    Text(client.address)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if !client.phone.isEmpty {
                    Image(systemName: "phone.fill")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(Client.jobSummary(for: jobCount))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// Detail screen
struct ClientDetailView: View {
    @Binding var client: Client
    @EnvironmentObject private var jobVM: JobViewModel

    var body: some View {
        let jobCount = jobVM.jobCount(for: client)

        ScrollView {
            VStack(spacing: 16) {
                ClientEditableCard(client: $client, jobCount: jobCount)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .navigationTitle(client.name.isEmpty ? "New Client" : client.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.40, blue: 0.50),
                    Color(red: 0.16, green: 0.18, blue: 0.40)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

// Compact row in list
private struct ClientSummaryRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 16) {
            ClientAvatar(initials: client.initials)

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name.isEmpty ? "New client" : client.name)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                if !client.company.isEmpty {
                    Text(client.company)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }

                if !client.address.isEmpty {
                    Text(client.address)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            if !client.phone.isEmpty {
                Image(systemName: "phone.fill")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
// MARK: - Settings tab

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    CompanyDetailsView()
                } label: {
                    SettingRow(icon: "building.2.fill", title: "Company details")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    BrandingLogoView()
                } label: {
                    SettingRow(icon: "paintpalette.fill", title: "Branding & logo")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    EstimateDefaultsView()
                } label: {
                    SettingRow(icon: "doc.text.fill", title: "Estimate defaults")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    SettingRow(icon: "lock.fill", title: "Privacy & security")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
            .navigationTitle("Settings")
        }
    }
}

private struct SettingRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundColor(.white)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Company details

struct CompanyDetailsView: View {
    @EnvironmentObject private var companySettings: CompanySettingsStore

    var body: some View {
        Form {
            Section("Company") {
                TextField("Company name", text: $companySettings.companyName)
                TextField("Address", text: $companySettings.companyAddress)
                TextField("Phone", text: $companySettings.companyPhone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $companySettings.companyEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
        .navigationTitle("Company details")
    }
}

// MARK: - Branding & logo

struct BrandingLogoView: View {
    @AppStorage("brandingLogoData") private var brandingLogoData: Data = Data()
    @State private var selectedItem: PhotosPickerItem?
    @State private var logoImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                logoPreview

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.headline)
                        Text("Choose logo from Photos")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedItem) { newItem in
                    Task {
                        guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                        brandingLogoData = data
                        logoImage = UIImage(data: data)
                    }
                }

                Text("Your logo will appear on estimates and invoices where you add it later.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Branding & logo")
        .onAppear(perform: loadStoredLogo)
    }

    @ViewBuilder
    private var logoPreview: some View {
        if let logoImage {
            Image(uiImage: logoImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 240)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 8)
                .padding(.top, 12)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Text("No logo yet")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: 260, minHeight: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(.white.opacity(0.35))
            )
            .padding(.top, 12)
        }
    }

    private func loadStoredLogo() {
        guard !brandingLogoData.isEmpty else { return }
        logoImage = UIImage(data: brandingLogoData)
    }
}

// MARK: - Estimate defaults

struct EstimateDefaultsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var newName: String = ""
    @State private var newPrice: String = ""

    var body: some View {
        List {
            Section("Common materials") {
                if settingsManager.commonMaterials.isEmpty {
                    Text("Add materials you use all the time (e.g., \"1/2\" drywall sheet\", \"Cement mix\").")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(settingsManager.commonMaterials.enumerated()), id: \.element.id) { index, _ in
                        HStack(spacing: 12) {
                            TextField(
                                "Material",
                                text: Binding(
                                    get: { settingsManager.commonMaterials[index].name },
                                    set: { settingsManager.updateMaterialName(at: index, name: $0) }
                                )
                            )

                            Spacer()

                            TextField(
                                "Price",
                                value: Binding(
                                    get: { settingsManager.commonMaterials[index].price },
                                    set: { settingsManager.updateMaterialPrice(at: index, price: $0) }
                                ),
                                format: .number
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                        }
                    }
                    .onDelete(perform: settingsManager.deleteMaterials)
                }
            }

            Section("Add new") {
                HStack(spacing: 12) {
                    TextField("Material name", text: $newName)

                    Spacer()

                    TextField("Price", text: $newPrice)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)

                    Button {
                        addMaterial()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(!canAddMaterial)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(Color.clear)
        .navigationTitle("Estimate defaults")
    }

    private var canAddMaterial: Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && Double(newPrice) != nil
    }

    private func addMaterial() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let priceValue = Double(newPrice), !trimmedName.isEmpty else { return }

        settingsManager.addMaterial(name: trimmedName, price: priceValue)
        newName = ""
        newPrice = ""
    }
}

// MARK: - Privacy policy

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy & Security")
                    .font(.title.bold())

                Text("""
Estimator Pro is designed for contractors, not data brokers. This app stores your information so you can manage jobs, clients, estimates, and invoices more efficiently.

1. Data we store

Company details (name, address, phone, email)

Client information (names, contact details, notes)

Job, estimate, and invoice data (descriptions, prices, dates)

All of this data is stored on your device and/or in your chosen backup service depending on how your device is configured.

2. How your data is used

Your data is used only to power features inside Estimator Pro, such as:

Creating and updating estimates and invoices

Linking jobs to clients

Generating totals and summaries

We do not sell your data, rent it, or use it for advertising.

3. Sync, backup, and third-party services

If you enable device backup or cloud sync, your data may be stored and backed up by those services under their own privacy policies.

If you choose to connect integrations in the future (for example, calendar or email), only the minimum necessary data will be shared to make those features work.

4. Security

Sensitive business data is stored using the system’s secure storage mechanisms where appropriate.

You are responsible for protecting access to your device (password, Face ID, Touch ID, etc.).

Do not share screenshots or exported files with anyone you do not trust.

5. Your choices

You can:

Edit or delete clients, jobs, estimates, and invoices from within the app

Delete the app from your device at any time (this removes local data that is not backed up elsewhere)

6. Changes to this policy

This privacy policy may be updated over time as new features are added. Updated versions will be included in the app.

7. Contact

If you have questions or concerns about privacy or data handling in Estimator Pro, contact your company’s administrator or the app developer using the email listed on the App Store page.
""")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy & security")
    }
}
