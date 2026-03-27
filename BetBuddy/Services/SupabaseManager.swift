import Foundation
import Supabase

enum SupabaseManager {
    static let client: SupabaseClient = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let urlString = config["SUPABASE_URL"] as? String,
              let anonKey = config["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString)
        else {
            fatalError("Missing or invalid Config.plist. Ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }()
}
