/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2023, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import ArgumentParser
import Cocoa

let baseImageHeight = 2880.0
let baseLogoHeight  = 300.0
let baseLogoMarginX = 100.0
let baseLogoMarginY = 120.0

enum ImageType
{
    case png
    case jpeg
    case both
}

let sizes = [
    ( width: 3840.0, height: 2880.0, logo: true,  type: ImageType.both, name: "3.4-3840x2880" ),
    ( width: 3840.0, height: 2160.0, logo: true,  type: ImageType.both, name: "4K-16.9-3840x2160" ),
    ( width: 5120.0, height: 2880.0, logo: true,  type: ImageType.both, name: "5K-16.9-5120x2880" ),
    ( width: 2560.0, height: 1664.0, logo: true,  type: ImageType.both, name: "16.10-2560x1664" ),
    ( width: 2880.0, height: 1864.0, logo: true,  type: ImageType.both, name: "16.10-2880x1864" ),
    ( width: 3024.0, height: 1964.0, logo: true,  type: ImageType.both, name: "16.10-3024x1964" ),
    ( width: 3456.0, height: 2234.0, logo: true,  type: ImageType.both, name: "16.10-3456x2234" ),
    ( width: 3440.0, height: 1440.0, logo: true,  type: ImageType.both, name: "Ultra-Wide-3440x1440" ),
    ( width: 6880.0, height: 2880.0, logo: true,  type: ImageType.both, name: "Ultra-Wide-6880x2880" ),
    ( width: 840.0,  height: 450.0,  logo: false, type: ImageType.jpeg, name: "Preview" ),
]

struct Options: ParsableArguments
{
    @Option( name: .short, help: "Logo image." )   var logo:   String
    @Option( name: .short, help: "Source image." ) var source: String
}

let options     = Options.parseOrExit()
let logo        = URL( filePath: options.logo )
let source      = URL( filePath: options.source )

if FileManager.default.fileExists( atPath: logo.path( percentEncoded: false ) ) == false
{
    print( "Error - File does not exist: \( logo.lastPathComponent )" )
    exit( -1 )
}

if FileManager.default.fileExists( atPath: source.path( percentEncoded: false ) ) == false
{
    print( "Error - File does not exist: \( source.lastPathComponent )" )
    exit( -1 )
}

guard let logoImage  = NSImage( contentsOf: logo )
else
{
    print( "Cannot read logo: \( logo.lastPathComponent )" )
    exit( -1 )
}

do
{
    try autoreleasepool
    {
        guard let sourceImage = NSImage( contentsOf: source )
        else
        {
            print( "Cannot read source image: \( source.lastPathComponent )" )
            exit( -1 )
        }

        try sizes.forEach
        {
            info in try autoreleasepool
            {
                print( "Reading image \( source.lastPathComponent ): \( Int( sourceImage.size.width ) ) x \( Int( sourceImage.size.height ) )" )

                let parent      = source.deletingLastPathComponent()
                let dir         = parent.appendingPathComponent( info.name )
                let name        = source.deletingPathExtension().lastPathComponent

                try FileManager.default.createDirectory( at: dir, withIntermediateDirectories: true )

                let logoHeight  = baseLogoHeight * ( info.height / baseImageHeight )
                let logoWidth   = ( logoHeight * logoImage.size.width ) / logoImage.size.height
                let logoMarginX = ( logoHeight * baseLogoMarginX ) / baseLogoHeight
                let logoMarginY = ( logoHeight * baseLogoMarginY ) / baseLogoHeight

                print( "    - Logo size:    \( logoWidth ) x \( logoHeight )" )
                print( "    - Logo margins: \( logoMarginX ) | \( logoMarginY )" )

                logoImage.size = NSSize( width: logoWidth, height: logoHeight )
                let image      = NSImage( size: NSSize( width: info.width, height: info.height ) )

                print( "    - Drawing..." )

                let width = ( image.size.height * sourceImage.size.width ) / sourceImage.size.height

                image.lockFocus()
                sourceImage.draw( in: NSRect( x: -( ( width - image.size.width ) / 2 ), y: 0, width: width, height: image.size.height ) )

                if info.logo
                {
                    logoImage.draw( at: NSPoint( x: ( image.size.width - logoImage.size.width ) - logoMarginX, y: logoMarginY ), from: .zero, operation: .sourceOver, fraction: 1 )
                }

                image.unlockFocus()

                guard let data = image.tiffRepresentation
                else
                {
                    print( "Cannot generate a TIFF representation" )
                    exit( -1 )
                }

                guard let rep = NSBitmapImageRep( data: data )
                else
                {
                    print( "Cannot create an image representation from TIFF data" )
                    exit( -1 )
                }

                let jpeg: () throws -> Void =
                {
                    guard let jpeg = rep.representation( using: .jpeg, properties: [ : ] )
                    else
                    {
                        print( "Cannot generate a PNG representation" )
                        exit( -1 )
                    }

                    let destination = dir.appendingPathComponent( "\( name )-\( info.name ).jpg" )

                    print( "    - Writing JPEG image: \( destination.lastPathComponent )" )
                    try jpeg.write( to: destination )
                }

                let png: () throws -> Void =
                {
                    guard let png = rep.representation( using: .png, properties: [ : ] )
                    else
                    {
                        print( "Cannot generate a PNG representation" )
                        exit( -1 )
                    }

                    let destination = dir.appendingPathComponent( "\( name )-\( info.name ).png" )

                    print( "    - Writing PNG image: \( destination.lastPathComponent )" )
                    try png.write( to: destination )
                }

                if info.type == .jpeg
                {
                    try jpeg()
                }
                else if info.type == .png
                {
                    try png()
                }
                else
                {
                    try png()
                    try jpeg()
                }
            }
        }
    }
}
catch
{
    print( error.localizedDescription )
    exit( -1 )
}
