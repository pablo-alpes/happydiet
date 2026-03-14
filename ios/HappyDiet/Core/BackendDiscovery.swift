//
//  BackendDiscovery.swift
//  HappyDiet
//
//  Automatically discovers the backend on the local network when running on a physical device.
//  Scans subnets from plist config (BACKEND_DISCOVERY_SUBNETS) or the device's own subnet.
//  No hardcoded subnets — fully configurable per rollout (local dev vs cloud).
//

import Foundation


enum BackendDiscovery {
    private static let discoveredURLKey = "happydiet_discovered_backend_url"
    private static let timeout: TimeInterval = 0.8

    /// Returns the last successfully discovered backend URL, or nil.
    static var discoveredURL: String? {
        get { UserDefaults.standard.string(forKey: discoveredURLKey) }
        set { UserDefaults.standard.set(newValue, forKey: discoveredURLKey) }
    }

    /// Whether discovery is enabled (from plist). Default true for local dev.
    static var isEnabled: Bool {
        guard let dict = plistDict else { return true }
        if let v = dict["BACKEND_DISCOVERY_ENABLED"] as? Bool { return v }
        return true
    }

    /// Discover backend on local network. Runs on background. Calls completion with URL if found.
    static func discover(completion: @escaping (String?) -> Void) {
        #if targetEnvironment(simulator)
        completion(nil)
        return
        #else
        guard isEnabled else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let port = discoveryPort
        let path = discoveryPath
        DispatchQueue.global(qos: .userInitiated).async {
            let candidates = buildCandidateIPs()
            for ip in candidates {
                let urlString = "http://\(ip):\(port)\(path)"
                if checkHealth(urlString: urlString) {
                    let baseURL = "http://\(ip):\(port)"
                    DispatchQueue.main.async {
                        discoveredURL = baseURL
                        completion(baseURL)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                completion(nil)
            }
        }
        #endif
    }

    /// Check if a URL responds to /health.
    static func checkHealth(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        var ok = false
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + timeout + 1)
        return ok
    }

    // MARK: - Plist config (no hardcoded defaults)

    private static var plistDict: [String: Any]? {
        guard let path = Bundle.main.path(forResource: "HappyDietConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else { return nil }
        return dict
    }

    private static var discoveryPort: Int {
        guard let dict = plistDict, let v = dict["BACKEND_DISCOVERY_PORT"] as? Int else { return 8080 }
        return v
    }

    private static var discoveryPath: String {
        guard let dict = plistDict, let s = dict["BACKEND_DISCOVERY_PATH"] as? String, !s.isEmpty else {
            return "/health"
        }
        return s.hasPrefix("/") ? s : "/" + s
    }

    /// Build list of IPs to try. Uses BACKEND_DISCOVERY_SUBNETS from plist if set;
    /// otherwise only the device's own subnet (derived from its IP). No hardcoded fallbacks.
    private static func buildCandidateIPs() -> [String] {
        var prefixes: [String] = []

        // 1. Plist: explicit subnet prefixes (e.g. ["192.168.1.", "10.0.0."] for custom rollouts)
        if let dict = plistDict, let arr = dict["BACKEND_DISCOVERY_SUBNETS"] as? [String] {
            for p in arr where !p.isEmpty {
                let prefix = p.hasSuffix(".") ? p : p + "."
                prefixes.append(prefix)
            }
        }

        // 2. Device subnet (dynamic, no hardcoding)
        if prefixes.isEmpty, let deviceIP = getDeviceIP(), let prefix = subnetPrefix(deviceIP) {
            prefixes.append(prefix)
        }

        // Build IP list from prefixes
        var candidates: [String] = []
        let rangeSize = 50
        for prefix in prefixes {
            for i in 1...rangeSize {
                candidates.append("\(prefix)\(i)")
            }
        }
        return candidates
    }

    /// Get device's WiFi/local IP (e.g. "192.168.1.105").
    private static func getDeviceIP() -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = ptr {
            defer { ptr = iface.pointee.ifa_next }
            guard let addr = iface.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.pointee.ifa_name)
            guard name == "en0" || name == "en1" || name.hasPrefix("en") else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(MemoryLayout<sockaddr_in>.size),
                             &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ip = String(cString: hostname)
            if !ip.hasPrefix("127.") { return ip }
        }
        return nil
        #endif
    }

    /// Extract subnet prefix from IP (e.g. "192.168.1.105" -> "192.168.1.").
    private static func subnetPrefix(_ ip: String) -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return parts.dropLast().joined(separator: ".") + "."
    }
}
