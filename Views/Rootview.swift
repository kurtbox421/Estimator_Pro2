//
//  Rootview.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case estimates = "Estimates"
    case invoices  = "Invoices"
    case clients   = "Clients"
    case settings  = "Settings"
}

private struct AdaptiveLayout {
    let contentWidth: CGFloat
    let horizontalPadding: CGFloat

    init(containerSize: CGSize,
         maxContentWidth: CGFloat = 860,
         minPadding: CGFloat = 16,
         minContentWidth: CGFloat = 320) {
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

struct RootView: View {
    @EnvironmentObject private var jobVM: JobViewModel
    @EnvironmentObject private var clientVM: ClientViewModel
    @State private var selectedTab: AppTab = .estimates
    @State private var showingAddJob = false
    @State private var invoiceSheetMode: AddEditInvoiceView.Mode?


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
    }

    // MARK: - Header with tabs + buttons

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
                    withAnimation {
                        clientVM.add()
                    }
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
                // later: quick action / AI tools, whatever
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

    // MARK: - Hero card at top

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

    // MARK: - Tab content

    @ViewBuilder
    private var contentForSelectedTab: some View {
        switch selectedTab {
        case .estimates:
            EstimatesTabView()
        case .invoices:
            InvoicesTabView { invoice in
                invoiceSheetMode = .edit(invoice)
            }
        case .clients:
            ClientsTabView()
        case .settings:
            SettingsTabView()
        }
    }

    // MARK: - Background colors

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
                Text("No estimates yet. Tap the + button (coming soon) to add your first job.")
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
                    // later: open job detail
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
                Label("$\(job.total, specifier: "%.2f")", systemImage: "dollarsign.circle.fill")
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
    var onSelectInvoice: (Invoice) -> Void = { _ in }
    private let rowInsets = EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24)

    var body: some View {
        List {
            ForEach(invoiceVM.invoices) { invoice in
                InvoiceCard(invoice: invoice)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectInvoice(invoice) }
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

// MARK: - Clients tab

struct ClientsTabView: View {
    @EnvironmentObject private var clientVM: ClientViewModel
    private let rowInsets = EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24)

    var body: some View {
        List {
            ForEach($clientVM.clients) { $client in
                ClientEditableCard(client: $client)
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                clientVM.delete(client.wrappedValue)
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

            addClientButton
                .listRowInsets(rowInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var addClientButton: some View {
        Button {
            withAnimation {
                clientVM.add()
            }
        } label: {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.headline)
                Text("Add client")
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

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
                    Text("Due \(dueDate, formatter: invoiceDueDateFormatter)")
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

                Text("$\(invoice.amount, specifier: "%.2f")")
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

private let invoiceDueDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

private extension Invoice.InvoiceStatus {
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

private struct ClientEditableCard: View {
    @Binding var client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ClientAvatar(initials: client.initials)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Client name", text: $client.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    TextField("Company", text: $client.company)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            ClientEditableField(
                title: "Address",
                prompt: "Street, city, state",
                systemImage: "mappin.and.ellipse",
                text: $client.address
            )

            HStack(spacing: 12) {
                ClientEditableField(
                    title: "Phone",
                    prompt: "(555) 123-4567",
                    systemImage: "phone.fill",
                    text: $client.phone,
                    capitalization: .never,
                    keyboardType: .phonePad
                )

                ClientEditableField(
                    title: "Email",
                    prompt: "hello@example.com",
                    systemImage: "envelope.fill",
                    text: $client.email,
                    capitalization: .never,
                    keyboardType: .emailAddress
                )
            }

            ClientEditableField(
                title: "Notes",
                prompt: "Reminders, preferences, etc.",
                systemImage: "note.text",
                text: $client.notes,
                capitalization: .sentences,
                disableAutocorrection: false
            )

            Stepper(value: $client.jobCount, in: 0...999) {
                Label(client.jobSummary, systemImage: "briefcase.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct ClientAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            Text(initials)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(width: 54, height: 54)
    }
}

private struct ClientEditableField: View {
    let title: String
    let prompt: String
    let systemImage: String?
    @Binding var text: String
    var capitalization: TextInputAutocapitalization = .words
    var keyboardType: UIKeyboardType = .default
    var disableAutocorrection: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.65))

            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                }

                TextField(prompt, text: $text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(disableAutocorrection)
                    .keyboardType(keyboardType)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Settings tab

struct SettingsTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingRow(icon: "building.2.fill", title: "Company details")
            settingRow(icon: "paintpalette.fill", title: "Branding & logo")
            settingRow(icon: "doc.text.fill", title: "Estimate defaults")
            settingRow(icon: "lock.fill", title: "Privacy & security")
        }
    }

    private func settingRow(icon: String, title: String) -> some View {
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

