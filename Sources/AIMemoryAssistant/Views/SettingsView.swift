import SwiftUI

/// Settings view with privacy controls and preferences.
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("clipboardMonitoring") private var clipboardEnabled = true
    @AppStorage("fileScanning") private var fileScanEnabled = true
    @AppStorage("retentionDays") private var retentionDays = 30

    @State private var showClearAlert = false
    @State private var memoryCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(hue: 0.6, saturation: 0.5, brightness: 0.1),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Privacy Section
                        settingsSection(title: "Privacy", icon: "lock.shield.fill", color: .green) {
                            VStack(spacing: 0) {
                                SettingsToggle(
                                    title: "Clipboard Monitoring",
                                    subtitle: "Automatically capture copied text",
                                    icon: "doc.on.clipboard",
                                    color: .cyan,
                                    isOn: $clipboardEnabled
                                )
                                Divider().overlay(.white.opacity(0.1))
                                SettingsToggle(
                                    title: "File Scanning",
                                    subtitle: "Watch Documents folder for files",
                                    icon: "folder.fill",
                                    color: .orange,
                                    isOn: $fileScanEnabled
                                )
                            }
                        }

                        // Data Section
                        settingsSection(title: "Data Management", icon: "externaldrive.fill", color: .blue) {
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Memory Retention")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text("Auto-delete memories older than")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Picker("", selection: $retentionDays) {
                                        Text("7 days").tag(7)
                                        Text("30 days").tag(30)
                                        Text("90 days").tag(90)
                                        Text("1 year").tag(365)
                                        Text("Forever").tag(0)
                                    }
                                    .tint(.purple)
                                }
                                .padding(14)

                                Divider().overlay(.white.opacity(0.1))

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Stored Memories")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text("\(memoryCount) items")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Button("Reindex Spotlight") {
                                        SpotlightIndexer.reindexAll(context: viewContext)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                }
                                .padding(14)
                            }
                        }

                        // Integration Section
                        settingsSection(title: "Integrations", icon: "puzzlepiece.fill", color: .purple) {
                            VStack(spacing: 0) {
                                integrationRow(
                                    title: "Siri Integration",
                                    subtitle: "\"Recall [query] in RecallMate\"",
                                    icon: "mic.fill",
                                    color: .purple,
                                    status: "Active"
                                )
                                Divider().overlay(.white.opacity(0.1))
                                integrationRow(
                                    title: "Spotlight Search",
                                    subtitle: "Memories appear in system search",
                                    icon: "magnifyingglass",
                                    color: .blue,
                                    status: "Active"
                                )
                            }
                        }

                        // Danger Zone
                        settingsSection(title: "Danger Zone", icon: "exclamationmark.triangle.fill", color: .red) {
                            Button {
                                showClearAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundStyle(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Clear All Memories")
                                            .font(.subheadline)
                                            .foregroundStyle(.red)
                                        Text("Permanently delete everything")
                                            .font(.caption2)
                                            .foregroundStyle(.red.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.5))
                                }
                                .padding(14)
                            }
                        }

                        // About
                        VStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("RecallMate")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("Privacy-first • On-device AI • v1.0")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.purple)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .alert("Clear All Memories?", isPresented: $showClearAlert) {
                Button("Clear All", role: .destructive) { clearAllMemories() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all stored memories and remove them from Spotlight. This cannot be undone.")
            }
            .onAppear { updateCount() }
        }
    }

    // MARK: – Helpers

    private func settingsSection<Content: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
            }

            content()
                .glassBackground(cornerRadius: 14)
        }
    }

    private func integrationRow(title: String, subtitle: String, icon: String, color: Color, status: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Text(status)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.green.opacity(0.2)))
                .foregroundStyle(.green)
        }
        .padding(14)
    }

    private func clearAllMemories() {
        let request = MemoryItem.fetchRequest()
        guard let items = try? viewContext.fetch(request) else { return }
        for item in items { viewContext.delete(item) }
        try? viewContext.save()
        SpotlightIndexer.deindexAll()
        updateCount()
    }

    private func updateCount() {
        let request = MemoryItem.fetchRequest()
        memoryCount = (try? viewContext.count(for: request)) ?? 0
    }
}

// MARK: – SettingsToggle

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .tint(.purple)
        .padding(14)
    }
}
