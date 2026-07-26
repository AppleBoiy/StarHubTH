import Foundation

/// Pure `Decodable` response models for `LiveNexusAPIClient` (§ file-size convention
/// split, see LiveNexusAPIClient.swift's header comment). No logic here beyond
/// `categoryTag`'s lookup table, so no cross-file visibility concerns from the split.
extension LiveNexusAPIClient {

    // MARK: - API Models

    struct ModInfo: Decodable {
        let name: String
        let summary: String
        let description: String
        let pictureUrl: String?
        let version: String?
        let author: String?
        let categoryId: Int?

        enum CodingKeys: String, CodingKey {
            case name
            case summary
            case description
            case pictureUrl = "picture_url"
            case version
            case author
            case categoryId = "category_id"
        }
    }

    /// Map Nexus Mods category ID for Stardew Valley to our internal Tag strings
    static func categoryTag(from categoryId: Int) -> String {
        switch categoryId {
        case 2: return "tag_nexus_2"
        case 3: return "tag_nexus_3"
        case 4: return "tag_nexus_4"
        case 5: return "tag_nexus_5"
        case 6: return "tag_nexus_6"
        case 7: return "tag_nexus_7"
        case 8: return "tag_nexus_8"
        case 9: return "tag_nexus_9"
        case 10: return "tag_nexus_10"
        case 11: return "tag_nexus_11"
        case 12: return "tag_nexus_12"
        case 13: return "tag_nexus_13"
        case 14: return "tag_nexus_14"
        case 15: return "tag_nexus_15"
        case 16: return "tag_nexus_16"
        case 17: return "tag_nexus_17"
        case 18: return "tag_nexus_18"
        case 19: return "tag_nexus_19"
        case 20: return "tag_nexus_20"
        case 21: return "tag_nexus_21"
        case 22: return "tag_nexus_22"
        case 23: return "tag_nexus_23"
        case 24: return "tag_nexus_24"
        case 25: return "tag_nexus_25"
        case 26: return "tag_nexus_26"
        case 27: return "tag_nexus_27"
        default: return "Other"
        }
    }

    struct ModFile: Decodable {
        let fileId: Int
        let name: String
        let version: String
        let categoryId: Int
        let changelogHtml: String?

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case name
            case version
            case categoryId = "category_id"
            case changelogHtml = "changelog_html"
        }
    }

    struct ModFileListResponse: Decodable {
        let files: [ModFile]
    }

    struct ModDownloadLink: Decodable {
        let name: String
        let shortName: String
        let URI: String

        enum CodingKeys: String, CodingKey {
            case name
            case shortName = "short_name"
            case URI
        }
    }

    // MARK: - GraphQL Models

    struct GraphQLResponse<T: Decodable>: Decodable {
        let data: T?
        let errors: [GraphQLError]?
    }

    struct GraphQLError: Decodable {
        let message: String
    }

    struct CollectionData: Decodable {
        let collection: CollectionGraph?
    }

    struct CollectionGraph: Decodable {
        let id: Int
        let slug: String
        let name: String
        let summary: String?
        let endorsements: Int?
        let totalDownloads: Int?
        let updatedAt: String?
        let tileImage: CollectionImage?
        let user: CollectionUser?
        let latestPublishedRevision: CollectionRevision?
        let game: CollectionGame?
    }

    struct CollectionUser: Decodable {
        let name: String?
    }

    struct CollectionImage: Decodable {
        let url: String?
    }

    struct CollectionRevision: Decodable {
        let revisionNumber: Int
        let downloadLink: String?
        let modFiles: [CollectionModFile]?
        let gameVersions: [CollectionGameVersion]?
    }

    struct CollectionGameVersion: Decodable {
        let reference: String?
    }

    struct CollectionModFile: Decodable {
        let fileId: Int?
        let optional: Bool?
        let file: CollectionFileDetail?
    }

    struct CollectionFileDetail: Decodable {
        let fileId: Int
        let name: String
        let version: String?
        let sizeInBytes: String?
        let mod: CollectionModDetail?
    }

    struct CollectionModDetail: Decodable {
        let modId: Int
        let name: String
        let pictureUrl: String?
        let author: String?
        let downloads: Int?
        let updatedAt: String?
        let thumbnailUrl: String?
    }

    struct CollectionGame: Decodable {
        let domainName: String
    }
}
