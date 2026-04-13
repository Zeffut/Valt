// Valt/UI/Views/PreviewView.swift
import SwiftUI
import AppKit

struct PreviewView: View {
    let item: ClipItem

    var body: some View {
        switch item.type {
        case "image":
            imagePreview
        case "url":
            urlPreview
        default:
            textPreview
        }
    }

    private var textPreview: some View {
        Text(item.plainText ?? "")
            .font(.system(size: 12))
            .lineLimit(4)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
    }

    private var urlPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
            Text(item.plainText ?? "")
                .font(.system(size: 11))
                .lineLimit(3)
                .foregroundStyle(.blue)
                .truncationMode(.middle)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var imagePreview: some View {
        Group {
            if let img = NSImage(data: item.content) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
