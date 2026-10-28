import XCTest
@testable import IgnitionCore

final class IgnitionCoreTests: XCTestCase {
    func testCatalogIDsAreUnique() {
        let ids = PreferenceCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testMergeLaterProfileWins() {
        var base = Profile(title: "Base")
        base.preferences["dock.tilesize"] = .int(32)
        base.packages.casks = [PackageEntry(name: "fork")]
        var work = Profile(title: "Work")
        work.preferences["dock.tilesize"] = .int(48)
        work.packages.casks = [PackageEntry(name: "fork"), PackageEntry(name: "figma")]
        let merged = Profile.merged([base, work])
        XCTAssertEqual(merged.preferences["dock.tilesize"], .int(48))
        XCTAssertEqual(merged.packages.casks.map(\.name), ["fork", "figma"])
    }

    func testRepositoryNormalization() {
        XCTAssertEqual(GitSync.normalize("marosige/private"), "https://github.com/marosige/private.git")
        XCTAssertEqual(GitSync.normalize("https://github.com/a/b"), "https://github.com/a/b.git")
    }

    func testSeedProfilesDecodeAndReferenceKnownPreferences() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("seed/ignition/profiles")
        for name in ["base", "personal", "work"] {
            let data = try Data(contentsOf: root.appendingPathComponent("\(name)/profile.json"))
            let profile = try JSONDecoder().decode(Profile.self, from: data)
            for id in profile.preferences.keys {
                XCTAssertNotNil(PreferenceCatalog.byID[id], "\(name): unknown preference \(id)")
            }
        }
    }

    func testBrewfileGeneration() {
        var p = Packages()
        p.casks = [PackageEntry(name: "fork", comment: "git client")]
        p.mas = [MasEntry(id: 1, name: "Magnet")]
        let text = Brew.brewfile(for: p)
        XCTAssertTrue(text.contains("cask \"fork\" # git client"))
        XCTAssertTrue(text.contains("mas \"Magnet\", id: 1"))
    }

    func testConfigFolderIsNormalized() {
        XCTAssertEqual(AppPaths.normalizeFolder("/ignition/"), "ignition")
        XCTAssertEqual(AppPaths.normalizeFolder("../x/./y"), "x/y")
        XCTAssertEqual(AppPaths.normalizeFolder(""), "ignition")
    }

    func testCommitMessageUsesCustomFolder() {
        let sync = GitSync(repository: "a/b", token: "t", deviceName: "Mac mini", configFolder: "me/mac")
        let msg = sync.commitMessage(for: ["me/mac/profiles/base/profile.json", "me/mac/profiles/work/dotfiles/.zshrc"])
        XCTAssertTrue(msg.hasPrefix("[Mac mini] Update base (settings), work (dotfiles)"))
    }
}
