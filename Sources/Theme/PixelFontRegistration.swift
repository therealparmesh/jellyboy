import CoreText
import Foundation

enum PixelFontRegistration {
    static func register() {
        guard let fontURL = Bundle.main.url(forResource: "jellyboy-pixel", withExtension: "ttf") else {
            return
        }
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }
}
