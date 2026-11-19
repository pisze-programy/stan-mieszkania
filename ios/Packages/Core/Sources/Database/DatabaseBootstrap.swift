import Foundation
import SQLiteData

public func makeAppDatabase(atPath path: String? = nil) throws -> any DatabaseWriter {
  let resolvedPath: String
  if let path {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    resolvedPath = url.path
  } else {
    let appSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    resolvedPath = appSupport.appendingPathComponent(DatabaseConstants.defaultFilename).path
  }

  let configuration = makeDatabaseConfiguration()
  let database = try DatabasePool(path: resolvedPath, configuration: configuration)
  try DatabaseMigrations.makeMigrator().migrate(database)
  return database
}

public func makeInMemoryDatabase() throws -> DatabaseQueue {
  let configuration = makeDatabaseConfiguration()
  let database = try DatabaseQueue(configuration: configuration)
  try DatabaseMigrations.makeMigrator().migrate(database)
  return database
}

private func makeDatabaseConfiguration() -> Configuration {
  var configuration = Configuration()
  configuration.foreignKeysEnabled = true
  configuration.prepareDatabase { db in
    try db.execute(sql: "PRAGMA foreign_keys = ON")
  }
  return configuration
}
