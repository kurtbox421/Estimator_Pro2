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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: AppTab = .estimates
    @State private var showingNewEstimate = false
    @State private var showingNewInvoice = false
    @State private var showingNewClient = false
    @State private var showingMaterialGenerator = false

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
                    topBar
                        .frame(maxWidth: layout.contentWidth, alignment: .center)

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
        .sheet(isPresented: $showingNewEstimate) {
            NavigationView {
                AddEditJobView(mode: .add)
            }
        }
        .sheet(isPresented: $showingNewInvoice) {
            NavigationView {
                AddEditInvoiceView(mode: .add)
            }
        }
        .sheet(isPresented: $showingMaterialGenerator) {
            MaterialGeneratorView()
        }
        .sheet(isPresented: $showingNewClient) {
            NewClientForm { newClient in
                clientVM.add(newClient)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                segmentedControl

                Spacer(minLength: 12)

                HStack(spacing: 12) {
                    if selectedTab != .settings {
                        Button {
                            switch selectedTab {
                            case .estimates:
                                showingNewEstimate = true
                            case .invoices:
                                showingNewInvoice = true
                            case .clients:
                                showingNewClient = true
                            case .settings:
                                break
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.95))
                                )
                        }
                    }

                    if selectedTab == .estimates {
                        Button {
                            showingMaterialGenerator = true
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18, weight: .semibold))
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.purple)
                                )
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }

    private var segmentedControl: some View {
        segmentedButtons(isCompact: horizontalSizeClass == .compact)
    }

    private func segmentedButtons(isCompact: Bool) -> some View {
        let spacing: CGFloat = isCompact ? 6 : 10
        let verticalPadding: CGFloat = isCompact ? 8 : 10
        let horizontalPadding: CGFloat = isCompact ? 14 : 18
        let backgroundPadding: CGFloat = isCompact ? 6 : 8

        return HStack(spacing: spacing) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab

                AppTabButton(
                    tab: tab,
                    isSelected: isSelected,
                    verticalPadding: verticalPadding,
                    horizontalPadding: horizontalPadding
                ) {
                    selectedTab = tab
                }
            }
        }
        .padding(backgroundPadding)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private struct AppTabButton: View {
        let tab: AppTab
        let isSelected: Bool
        let verticalPadding: CGFloat
        let horizontalPadding: CGFloat
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                buttonLabel
            }
        }

        private var buttonLabel: some View {
            let backgroundColor = isSelected
                ? Color.white
                : Color.white.opacity(0.14)

            let strokeOpacity: Double = isSelected ? 0.0 : 0.4
            let shadowOpacity: Double = isSelected ? 0.12 : 0
            let foregroundColor = isSelected
                ? Color.black.opacity(0.85)
                : Color.white

            return Text(tab.rawValue)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding)
                .background(Capsule().fill(backgroundColor))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .foregroundColor(foregroundColor)
        }
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
            // iterate jobs with index + value
            ForEach($vm.jobs) { $job in
                NavigationLink {
                    // pass a binding to this job
                    EstimateDetailView(estimate: $job)
                } label: {
                    EstimateJobCard(job: $job.wrappedValue)
                }
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            vm.delete($job.wrappedValue)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if vm.jobs.isEmpty {
                Text("No estimates yet. Tap the + button to add your first job.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.77))
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
            ForEach(invoiceVM.invoices.indices, id: \.self) { index in
                let invoiceBinding = $invoiceVM.invoices[index]
                let invoice = invoiceBinding.wrappedValue

                NavigationLink {
                    InvoiceDetailView(invoice: invoiceBinding)
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

                Text("Invoice #: \(invoice.invoiceNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))

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
    @Environment(\.openURL) private var openURL

    @State private var showingEditSheet = false
    @State private var draftClient: Client = .init()

    var body: some View {
        let jobCount = jobVM.jobCount(for: client)

        ScrollView {
            VStack(spacing: 16) {
                ClientEditableCard(
                    client: $client,
                    jobCount: jobCount,
                    isEditing: false,
                    onEdit: openEditSheet,
                    addressAction: openMaps,
                    phoneAction: callClient,
                    emailAction: emailClient
                )
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
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ClientEditableCard(client: $draftClient, jobCount: jobCount)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
                .navigationTitle("Edit client")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditSheet = false }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveEdits() }
                    }
                }
            }
        }
    }

    private func openEditSheet() {
        draftClient = client
        showingEditSheet = true
    }

    private func openMaps() {
        guard !client.address.isEmpty else { return }
        let query = client.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(query)") else { return }
        openURL(url)
    }

    private func callClient() {
        guard !client.phone.isEmpty else { return }
        let digits = client.phone.filter { $0.isNumber }
        guard !digits.isEmpty else { return }
        guard let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    private func emailClient() {
        guard !client.email.isEmpty else { return }
        let encoded = client.email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? client.email
        guard let url = URL(string: "mailto:\(encoded)") else { return }
        openURL(url)
    }

    private func saveEdits() {
        client = draftClient
        showingEditSheet = false
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
    @EnvironmentObject private var session: SessionViewModel

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
                    MaterialPricingSettingsView()
                } label: {
                    SettingRow(icon: "dollarsign.circle.fill", title: "Material generator pricing")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    ImportDataView()
                } label: {
                    SettingRow(icon: "square.and.arrow.down.on.square", title: "Import from other apps")
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

                Section {
                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.backward.circle.fill")
                                .font(.headline)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundColor(.white)

                            Text("Sign out")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
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
                        CommonMaterialRow(
                            name: nameBinding(for: index),
                            price: priceBinding(for: index)
                        )
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
        return !trimmedName.isEmpty && parseDouble(newPrice) != nil
    }

    private func addMaterial() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let priceValue = parseDouble(newPrice), !trimmedName.isEmpty else { return }

        let safePrice = debugCheckNaN(priceValue, label: "default material price")

        settingsManager.addMaterial(name: trimmedName, price: safePrice)
        newName = ""
        newPrice = ""
    }

    private func nameBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                guard settingsManager.commonMaterials.indices.contains(index) else { return "" }
                return settingsManager.commonMaterials[index].name
            },
            set: { settingsManager.updateMaterialName(at: index, name: $0) }
        )
    }

    private func priceBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: {
                guard settingsManager.commonMaterials.indices.contains(index) else { return 0 }
                return settingsManager.commonMaterials[index].price
            },
            set: { settingsManager.updateMaterialPrice(at: index, price: $0) }
        )
    }
}

private struct CommonMaterialRow: View {
    let name: Binding<String>
    let price: Binding<Double>

    var body: some View {
        HStack(spacing: 12) {
            TextField("Material", text: name)

            Spacer()

            TextField("Price", value: price, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
        }
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
