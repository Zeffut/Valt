// Valt/UI/Views/PinboardView.swift
import SwiftUI
import CoreData

struct PinboardView: View {
    let pinboards: [Pinboard]
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let context: NSManagedObjectContext

    @State private var selectedPinboard: Pinboard?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(pinboards, id: \.id) { pb in
                        Button(pb.name) {
                            selectedPinboard = pb
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selectedPinboard?.id == pb.id ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            selectedPinboard?.id == pb.id
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider()

            let current = selectedPinboard ?? pinboards.first
            if let pb = current {
                let items = pb.sortedItems
                if items.isEmpty {
                    ContentUnavailableView(
                        "Pinboard vide",
                        systemImage: "pin",
                        description: Text("Clic droit sur un item → Épingler ici")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(items, id: \.id) { item in
                                ClipCellView(
                                    item: item,
                                    onPaste: { onPaste(item) },
                                    onCopy: { onCopy(item) },
                                    onPin: nil
                                )
                                .contextMenu {
                                    Button("Détacher du pinboard") {
                                        item.pinboard = nil
                                        try? context.save()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
            } else {
                ContentUnavailableView("Aucun pinboard", systemImage: "pin.slash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedPinboard == nil {
                selectedPinboard = pinboards.first
            }
        }
    }
}
