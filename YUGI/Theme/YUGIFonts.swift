import SwiftUI

enum YUGIFontFamily {
    static let playfairDisplay = "PlayfairDisplay"
    static let montserrat = "Montserrat"
    static let roboto = "Roboto"
    static let bellotaText = "BellotaText"
}

extension Font {
    // Playfair Display fonts
    static func playfairDisplay(size: CGFloat) -> Font {
        .custom(YUGIFontFamily.playfairDisplay, size: size)
    }
    
    static func playfairDisplayBold(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.playfairDisplay)-Bold", size: size)
    }
    
    static func playfairDisplayBlack(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.playfairDisplay)-Black", size: size)
    }
    
    // Montserrat fonts
    static func montserrat(size: CGFloat) -> Font {
        .custom(YUGIFontFamily.montserrat, size: size)
    }
    
    static func montserratLight(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.montserrat)-Light", size: size)
    }
    
    static func montserratThin(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.montserrat)-Thin", size: size)
    }
    
    // Roboto fonts
    static func roboto(size: CGFloat) -> Font {
        .custom(YUGIFontFamily.roboto, size: size)
    }
    
    static func robotoThin(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.roboto)-Thin", size: size)
    }
    
    static func robotoLight(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.roboto)-Light", size: size)
    }
    
    // Bellota Text fonts
    static func bellotaTextLight(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.bellotaText)-Light", size: size)
    }
    
    static func bellotaTextRegular(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.bellotaText)-Regular", size: size)
    }
    
    static func bellotaTextBold(size: CGFloat) -> Font {
        .custom("\(YUGIFontFamily.bellotaText)-Bold", size: size)
    }
} 