import Foundation
import NaturalLanguage
import CoreData

/// Extracts named entities from memory content and builds a relationship graph.
class EntityExtractor: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var edges: [GraphEdge] = []

    private let viewContext: NSManagedObjectContext
    private let tagger: NLTagger

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.tagger = NLTagger(tagSchemes: [.nameType])
    }

    /// Extract entities from all memories and build the relationship graph.
    func buildGraph() async {
        let memories = fetchAllMemories()
        var entityMap: [String: GraphNode] = [:]
        var coOccurrences: [String: Set<String>] = [:]

        for memory in memories {
            let text = "\(memory.title) \(memory.content)"
            let entities = extractEntities(from: text)

            // Add categories as nodes too
            let categoryName = memory.category.displayName
            let categoryKey = "cat_\(categoryName)"
            if entityMap[categoryKey] == nil {
                entityMap[categoryKey] = GraphNode(
                    id: categoryKey,
                    label: categoryName,
                    type: .category,
                    weight: 1,
                    color: memory.category.rawValue
                )
            } else {
                entityMap[categoryKey]?.weight += 1
            }

            // Build entity nodes
            var memoryEntityKeys: [String] = [categoryKey]

            for entity in entities {
                let key = entity.label.lowercased()
                if entityMap[key] == nil {
                    entityMap[key] = GraphNode(
                        id: key,
                        label: entity.label,
                        type: entity.type,
                        weight: 1,
                        color: entity.type.colorName
                    )
                } else {
                    entityMap[key]?.weight += 1
                }
                memoryEntityKeys.append(key)
            }

            // Track co-occurrences for edges
            for key in memoryEntityKeys {
                if coOccurrences[key] == nil { coOccurrences[key] = Set() }
                coOccurrences[key]?.formUnion(memoryEntityKeys.filter { $0 != key })
            }
        }

        // Build edges from co-occurrences
        var edgeSet = Set<String>()
        var graphEdges: [GraphEdge] = []

        for (source, targets) in coOccurrences {
            for target in targets {
                let edgeKey = [source, target].sorted().joined(separator: "↔")
                if edgeSet.insert(edgeKey).inserted {
                    graphEdges.append(GraphEdge(
                        source: source,
                        target: target,
                        weight: 1
                    ))
                }
            }
        }

        await MainActor.run {
            self.nodes = Array(entityMap.values)
                .sorted { $0.weight > $1.weight }
                .prefix(40)
                .map { $0 }
            self.edges = graphEdges.filter { edge in
                nodes.contains { $0.id == edge.source } &&
                nodes.contains { $0.id == edge.target }
            }
        }
    }

    // MARK: – NLP Entity Extraction

    private func extractEntities(from text: String) -> [ExtractedEntity] {
        tagger.string = text
        var entities: [ExtractedEntity] = []

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            guard let tag else { return true }
            let value = String(text[range]).trimmingCharacters(in: .whitespaces)
            guard value.count > 1 else { return true }

            let type: GraphNodeType
            switch tag {
            case .personalName:  type = .person
            case .placeName:     type = .place
            case .organizationName: type = .organization
            default: return true
            }

            entities.append(ExtractedEntity(label: value, type: type))
            return true
        }

        // Also extract URLs as topic nodes
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsText = text as NSString
        detector?.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { result, _, _ in
            if let url = result?.url {
                entities.append(ExtractedEntity(
                    label: url.host ?? url.absoluteString.prefix(30).description,
                    type: .topic
                ))
            }
        }

        return entities
    }

    private func fetchAllMemories() -> [MemoryItem] {
        let request = MemoryItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MemoryItem.timestamp, ascending: false)]
        request.fetchLimit = 200
        return (try? viewContext.fetch(request)) ?? []
    }
}

// MARK: – Data Models

struct GraphNode: Identifiable, Equatable {
    let id: String
    let label: String
    let type: GraphNodeType
    var weight: Int
    let color: String

    // Position for rendering (mutable for physics simulation)
    var x: CGFloat = CGFloat.random(in: 50...300)
    var y: CGFloat = CGFloat.random(in: 50...500)
    var vx: CGFloat = 0
    var vy: CGFloat = 0

    var radius: CGFloat {
        CGFloat(min(max(weight * 4 + 12, 16), 40))
    }

    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        lhs.id == rhs.id
    }
}

enum GraphNodeType: String, Codable {
    case person
    case place
    case organization
    case topic
    case category

    var icon: String {
        switch self {
        case .person:       return "person.fill"
        case .place:        return "mappin.circle.fill"
        case .organization: return "building.2.fill"
        case .topic:        return "tag.fill"
        case .category:     return "square.grid.2x2.fill"
        }
    }

    var colorName: String {
        switch self {
        case .person:       return "green"
        case .place:        return "pink"
        case .organization: return "blue"
        case .topic:        return "orange"
        case .category:     return "purple"
        }
    }
}

struct GraphEdge: Identifiable {
    let id = UUID()
    let source: String
    let target: String
    let weight: Int
}

struct ExtractedEntity {
    let label: String
    let type: GraphNodeType
}
