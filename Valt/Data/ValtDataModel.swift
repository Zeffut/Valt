// Valt/Data/ValtDataModel.swift
import CoreData

extension NSManagedObjectModel {
    nonisolated(unsafe) static let valt: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        // ── Helper ───────────────────────────────────────────────────
        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }

        // ── ClipItem entity ──────────────────────────────────────────
        let clipEntity = NSEntityDescription()
        clipEntity.name = "ClipItem"
        clipEntity.managedObjectClassName = NSStringFromClass(ClipItem.self)
        clipEntity.properties = [
            attr("id",            .UUIDAttributeType),
            attr("content",       .binaryDataAttributeType),
            attr("type",          .stringAttributeType),
            attr("plainText",     .stringAttributeType, optional: true),
            attr("sourceApp",     .stringAttributeType, optional: true),
            attr("sourceAppName", .stringAttributeType, optional: true),
            attr("createdAt",     .dateAttributeType),
        ]

        // ── Pinboard entity ──────────────────────────────────────────
        let pbEntity = NSEntityDescription()
        pbEntity.name = "Pinboard"
        pbEntity.managedObjectClassName = NSStringFromClass(Pinboard.self)
        pbEntity.properties = [
            attr("id",       .UUIDAttributeType),
            attr("name",     .stringAttributeType),
            attr("position", .integer16AttributeType),
        ]

        // ── Relationships ────────────────────────────────────────────
        let toOne = NSRelationshipDescription()
        toOne.name = "pinboard"
        toOne.destinationEntity = pbEntity
        toOne.minCount = 0
        toOne.maxCount = 1
        toOne.isOptional = true
        toOne.deleteRule = .nullifyDeleteRule

        let toMany = NSRelationshipDescription()
        toMany.name = "items"
        toMany.destinationEntity = clipEntity
        toMany.minCount = 0
        toMany.maxCount = 0   // to-many
        toMany.isOptional = true
        toMany.deleteRule = .nullifyDeleteRule

        toOne.inverseRelationship = toMany
        toMany.inverseRelationship = toOne

        clipEntity.properties.append(toOne)
        pbEntity.properties.append(toMany)

        model.entities = [clipEntity, pbEntity]
        return model
    }()
}
