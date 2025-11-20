import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject var invoiceVM: InvoiceViewModel
    @EnvironmentObject var clientVM: ClientViewModel
    @EnvironmentObject var jobVM: JobViewModel

    let invoice: Invoice

    @State private var isShowingEditSheet = false

    private var associatedJob: Job? {
        jobVM.jobs.first { job in
            let matchesClient = invoice.clientId == nil || job.clientId == invoice.clientId
            return matchesClient && job.name == invoice.title
        }
    }

    private var formattedAmount: String {
        invoice.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.15, blue: 0.12),
                    Color(red: 0.20, green: 0.35, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                        .padding(.horizontal, 24)

                    if let job = associatedJob {
                        materialsCard(for: job)
                            .padding(.horizontal, 24)
                    }

                    invoiceDetailsCard
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(invoice.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isShowingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            NavigationView {
                AddEditInvoiceView(mode: .edit(invoice))
            }
            .environmentObject(invoiceVM)
            .environmentObject(clientVM)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(invoice.title)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(invoice.clientName)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            Divider().background(Color.white.opacity(0.25))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(formattedAmount)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(invoice.status.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(invoice.status.pillColor)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }

                Spacer()

                if let dueDate = invoice.dueDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due date")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(dueDate, formatter: invoiceDueDateFormatter)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.02),
                                    Color.black.opacity(0.40)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func materialsCard(for job: Job) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Materials")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(job.materials.count) items")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            if job.materials.isEmpty {
                Text("No materials listed for this invoice.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            } else {
                ForEach(job.materials) { material in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(material.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Text("\(material.quantity, specifier: "%.2f") × $\(material.unitCost, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Spacer()

                        Text("$\(material.cost, specifier: "%.2f")")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 6)
                }
            }
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

    private var invoiceDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice details")
                .font(.headline)
                .foregroundColor(.white)

            detailRow(title: "Client", value: invoice.clientName)
            detailRow(title: "Status", value: invoice.status.displayName)
            detailRow(title: "Amount", value: formattedAmount)
            detailRow(
                title: "Due date",
                value: invoice.dueDate.map { invoiceDueDateFormatter.string(from: $0) } ?? "Not set"
            )
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

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
}
