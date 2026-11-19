import Foundation

enum APITestJSONFixtures {
  static let publicConfigJSON = """
    {
      "minSupportedAppVersion": "1.2.0",
      "cloudMediaQuotaPerApartment": 250,
      "jpegCompression": {
        "maxDimensionPx": 3000,
        "quality": 0.8,
        "maxBytes": 3145728
      }
    }
    """

  static let apartmentJSON = """
    {
      "id": "\(MockTransportConstants.apartmentId)",
      "ownerId": "\(MockTransportConstants.ownerId)",
      "name": "Mieszkanie Mokotow",
      "street": "Pulawska 10",
      "city": "Warszawa",
      "role": "owner",
      "inviteCode": "K7QM4XPB",
      "shouldSuggestInviteCodeReset": false,
      "cloudMediaCount": 0,
      "createdAt": "2025-11-17T10:00:00.000Z",
      "updatedAt": "2025-11-17T10:00:00.000Z"
    }
    """

  static let entryJSON = """
    {
      "id": "\(MockTransportConstants.entryId)",
      "mediaId": "\(MockTransportConstants.mediaId)",
      "authorId": "\(MockTransportConstants.ownerId)",
      "author": {
        "userId": "\(MockTransportConstants.ownerId)",
        "displayName": "Anna Nowak",
        "shortTag": "A1B2",
        "color": "#007AFF",
        "role": "owner"
      },
      "text": "Rysa [2]",
      "markers": [
        {
          "id": "\(MockTransportConstants.markerId)",
          "entryId": "\(MockTransportConstants.entryId)",
          "mediaId": "\(MockTransportConstants.mediaId)",
          "number": 2,
          "x": 0.3,
          "y": 0.6
        }
      ],
      "createdAt": "2025-11-17T10:00:00.000Z",
      "serverReceivedAt": "2025-11-17T10:00:02.000Z",
      "retractedAt": null
    }
    """

  static let syncChangesPageJSON = """
    {
      "changes": [
        {
          "seq": 5,
          "apartmentId": "\(MockTransportConstants.apartmentId)",
          "entityType": "apartment",
          "entityId": "\(MockTransportConstants.apartmentId)",
          "op": "updated",
          "createdAt": "2025-11-17T10:05:00.000Z",
          "payload": {
            "kind": "apartment",
            "apartment": {
              "id": "\(MockTransportConstants.apartmentId)",
              "ownerId": "\(MockTransportConstants.ownerId)",
              "name": "Nowa Nazwa",
              "street": "Pulawska 10",
              "city": "Warszawa",
              "role": "owner",
              "inviteCode": "K7QM4XPB",
              "shouldSuggestInviteCodeReset": true,
              "cloudMediaCount": 1,
              "createdAt": "2025-11-17T10:00:00.000Z",
              "updatedAt": "2025-11-17T10:05:00.000Z"
            }
          }
        }
      ],
      "nextSeq": 5,
      "hasMore": false
    }
    """
}
