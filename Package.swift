// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "CryptoBuddy",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CryptoBuddy",
            targets: ["CryptoBuddy"]),
    ],
    dependencies: [
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.18.0"),
    ],
    targets: [
        .target(
            name: "CryptoBuddy",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase"),
                .product(name: "FirebaseFirestore", package: "Firebase"),
                .product(name: "FirebaseFirestoreSwift", package: "Firebase"),
            ]),
    ]
) 