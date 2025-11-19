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

struct RootView: View {
    @EnvironmentObject private var jobVM: JobViewModel
    @State private var selectedTab: AppTab = .estimates
    @State private var showingAddJob = false


    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors(for: selectedTab),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                headerBar

                ScrollView {
                    VStack(spacing: 20) {
                        heroCard
                        contentForSelectedTab
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 12)
        }
        .sheet(isPresented: $showingAddJob) {
            NavigationView {
                AddEditJobView(mode: .add)
            }
        }
    }

    // MARK: - Header with tabs + buttons

    private var headerBar: some View {
        HStack {
            // Tabs
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

            Spacer()

            // Right side buttons (only meaningful on Estimates for now)
            HStack(spacing: 10) {
                Button {
                    if selectedTab == .estimates {
                        showingAddJob = true
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
        .padding(.horizontal, 24)
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
            InvoicesTabView()
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

    var body: some View {
        VStack(spacing: 16) {
            ForEach(vm.jobs) { job in
                NavigationLink {
                    JobDetailView(job: job)
                } label: {
                    EstimateJobCard(job: job)
                }
                .buttonStyle(.plain)
            }

            if vm.jobs.isEmpty {
                Text("No estimates yet. Tap the + button (coming soon) to add your first job.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
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
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.image")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.8))

                        Text("No invoices yet")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Convert an estimate to create your first invoice. It will show up here for easy sharing and tracking.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(24)
                )
                .frame(maxWidth: .infinity, minHeight: 180)
        }
    }
}

// MARK: - Clients tab

struct ClientsTabView: View {
    private let clients: [ClientInfo] = [
        .init(
            name: "Johnny Appleseed",
            company: "B&B Apple Company",
            address: "123 Honeycrisp Dr • Cupertino, CA",
            jobs: 1,
            phone: "(234) 421-3860"
        ),
        .init(
            name: "Maria Sanchez",
            company: "Sunrise Renovations",
            address: "88 Goldenrod Ave • Portland, OR",
            jobs: 3,
            phone: "(503) 881-2244"
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(clients) { client in
                ClientBubbleCard(client: client)
            }

            if clients.isEmpty {
                Text("Add a client to start building your directory.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}

private struct ClientInfo: Identifiable {
    let id = UUID()
    let name: String
    let company: String
    let address: String
    let jobs: Int
    let phone: String

    var jobSummary: String {
        jobs == 1 ? "1 job" : "\(jobs) jobs"
    }
}

private struct ClientBubbleCard: View {
    let client: ClientInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(client.name) — \(client.company)")
                .font(.headline)
                .foregroundColor(.white)

            Text(client.address)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            HStack {
                Label(client.jobSummary, systemImage: "briefcase.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text(client.phone)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.top, 4)
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

