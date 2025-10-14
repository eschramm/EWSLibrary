//
//  File.swift
//  RepoArchiver2
//
//  Created by Eric Schramm on 9/23/25.
//

import Foundation

public struct DirectoryStats: Sendable {
    public let count: Int
    public let size: Int
    public let latestModifiedDate: Date?
    public let latestModifiedURL: URL?
    
    static var empty: Self {
        return .init(count: 0, size: 0, latestModifiedDate: nil, latestModifiedURL: nil)
    }
    
    static func + (lhs: Self, rhs: Self) -> Self {
        let latestModifiedDate: Date?
        let latestModifiedURL: URL?
        if let ld = lhs.latestModifiedDate {
            if let rd = rhs.latestModifiedDate {
                if ld > rd {
                    latestModifiedDate = ld
                    latestModifiedURL = lhs.latestModifiedURL
                } else {
                    latestModifiedDate = rd
                    latestModifiedURL = rhs.latestModifiedURL
                }
            } else {
                latestModifiedDate = ld
                latestModifiedURL = lhs.latestModifiedURL
            }
        } else if let rd = rhs.latestModifiedDate {
            latestModifiedDate = rd
            latestModifiedURL = rhs.latestModifiedURL
        } else {
            latestModifiedDate = nil
            latestModifiedURL = nil
        }
        return .init(
            count: lhs.count + rhs.count,
            size: lhs.size + rhs.size,
            latestModifiedDate: latestModifiedDate,
            latestModifiedURL: latestModifiedURL
        )
    }
}

private struct ScanChunk: Sendable {
    var stats: DirectoryStats
    var subdirs: [URLItem]
}

public enum FileCounterError: Error {
    case fileDoesntExist(URL)
    case vendedItemIsNotURL(String)
    case errorCreatingEnumerator
}

struct URLItem {
    let url: URL
    let isHidden: Bool
}

public actor FileCounter {
    
    public init() { }

    public nonisolated func scanDirectoryParallel(at url: URL, excludeLastModifiedForSpeed: Bool, maxConcurrentTasks: Int = 8) async throws -> DirectoryStats {
        let pool = AsyncSemaphore(limit: maxConcurrentTasks)
        return try await withThrowingTaskGroup(of: ScanChunk.self) { group in
            // Seed the root directory/file
            group.addTask {
                await pool.acquire()
                do {
                    let chunk = try await self.scanOne(URLItem(url: url, isHidden: false), excludeLastModifiedForSpeed: excludeLastModifiedForSpeed)
                    await pool.release()
                    return chunk
                } catch {
                    await pool.release()
                    throw error
                }
            }

            var total = DirectoryStats.empty

            for try await chunk in group {
                // Aggregate immediate stats
                total = total + .init(count: chunk.stats.count, size: chunk.stats.size, latestModifiedDate: chunk.stats.latestModifiedDate, latestModifiedURL: chunk.stats.latestModifiedURL)
                
                // Enqueue subdirectories, each bounded by the permit pool
                for subdir in chunk.subdirs {
                    group.addTask {
                        await pool.acquire()
                        do {
                            let subChunk = try await self.scanOne(subdir, excludeLastModifiedForSpeed: excludeLastModifiedForSpeed)
                            await pool.release()
                            return subChunk
                        } catch {
                            await pool.release()
                            throw error
                        }
                    }
                }
            }

            return total
        }
    }

    nonisolated private func scanOne(_ urlItem: URLItem, excludeLastModifiedForSpeed: Bool) async throws -> ScanChunk {
        var stats = DirectoryStats.empty
        let fm = FileManager()

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: urlItem.url.path, isDirectory: &isDir) else {
            throw FileCounterError.fileDoesntExist(urlItem.url)
        }

        // Skip Finder aliases and symlinks
        if let res = try? urlItem.url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey]),
           res.isAliasFile == true || res.isSymbolicLink == true {
            return ScanChunk(stats: stats, subdirs: [])
        }
        
        let keys: Set<URLResourceKey>
        if excludeLastModifiedForSpeed {
            keys = [.isDirectoryKey, .fileSizeKey]
        } else {
            keys = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
        }

        if isDir.boolValue {
            
            let contents = try fm.contentsOfDirectory(at: urlItem.url, includingPropertiesForKeys: Array(keys))
            var subdirs: [URLItem] = []

            for child in contents {
                var childIsDir: ObjCBool = false
                if fm.fileExists(atPath: child.path, isDirectory: &childIsDir), childIsDir.boolValue {
                    if !excludeLastModifiedForSpeed {
                        if urlItem.isHidden {
                            subdirs.append(URLItem(url: child, isHidden: true))
                        } else if let attrs = try? child.resourceValues(forKeys: keys) {
                            subdirs.append(URLItem(url: child, isHidden: attrs.isHidden ?? false))
                        } else {
                            subdirs.append(URLItem(url: child, isHidden: false))
                        }
                    } else {
                        subdirs.append(URLItem(url: child, isHidden: false))
                    }
                } else {
                    let attrs = try child.resourceValues(forKeys: keys)
                    if let size = attrs.fileSize {
                        if urlItem.isHidden {
                            stats = stats + .init(count: 1, size: size, latestModifiedDate: nil, latestModifiedURL: nil)
                        } else if let isHidden = attrs.isHidden, !isHidden, let modifiedDate = attrs.contentModificationDate {
                            stats = stats + .init(count: 1, size: size, latestModifiedDate: modifiedDate, latestModifiedURL: child)
                        } else {
                            stats = stats + .init(count: 1, size: size, latestModifiedDate: nil, latestModifiedURL: nil)
                        }
                    }
                }
            }

            return ScanChunk(stats: stats, subdirs: subdirs)
        } else {
            let attrs = try urlItem.url.resourceValues(forKeys: keys)
            if let size = attrs.fileSize {
                if let isHidden = attrs.isHidden, !isHidden, let modifiedDate = attrs.contentModificationDate {
                    stats = stats + .init(count: 1, size: size, latestModifiedDate: modifiedDate, latestModifiedURL: urlItem.url)
                } else {
                    stats = stats + .init(count: 1, size: size, latestModifiedDate: nil, latestModifiedURL: nil)
                }
            }
            return ScanChunk(stats: stats, subdirs: [])
        }
    }
    
    public func scanDirectorySerial(at url: URL, excludeLastModifiedForSpeed: Bool) throws -> DirectoryStats  {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw FileCounterError.fileDoesntExist(url)
        }
        let keys: Set<URLResourceKey>
        if excludeLastModifiedForSpeed {
            keys = [.isDirectoryKey, .fileSizeKey]
        } else {
            keys = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
        }
        if isDirectory.boolValue {
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) {
                var totalSize = 0
                var count = 0
                var lastModifiedURL: URL?
                var lastModifiedDate: Date?
                for item in enumerator {
                    if let urlItem = item as? URL {
                        var isUrlItemDirectory: ObjCBool = false
                        guard FileManager.default.fileExists(atPath: urlItem.path, isDirectory: &isUrlItemDirectory) else {
                            throw FileCounterError.fileDoesntExist(urlItem)
                        }
                        guard !isUrlItemDirectory.boolValue else { continue }
                        let attributes = try urlItem.resourceValues(forKeys: keys)
                        count += 1
                        totalSize += (attributes.fileSize ?? 0)
                        if !(attributes.isHidden ?? false), let lmd = attributes.contentModificationDate, lmd > (lastModifiedDate ?? .distantPast) {
                            lastModifiedDate = lmd
                            lastModifiedURL = urlItem
                        }
                    } else {
                        throw FileCounterError.vendedItemIsNotURL("\(item)")
                    }
                }
                return .init(
                    count: count,
                    size: totalSize,
                    latestModifiedDate: lastModifiedDate,
                    latestModifiedURL: lastModifiedURL
                )
            } else {
                throw FileCounterError.errorCreatingEnumerator
            }
        } else {
            let attributes = try url.resourceValues(forKeys: keys)
            return .init(
                count: 1,
                size: attributes.fileSize ?? 0,
                latestModifiedDate: (attributes.isHidden ?? false) ? nil : attributes.contentModificationDate,
                latestModifiedURL: (attributes.isHidden ?? false) ? nil : url
            )
        }
    }
}

