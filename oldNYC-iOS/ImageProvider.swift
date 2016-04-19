//
//  ImageProvider.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 18/03/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit

// allows very loose coupling of the image source and the gallery. You make whatever object conform to this protocol and pass a reference to youur object to the viewer. the viwer will at convenient times ask this object for an image (at index).
public protocol ImageProvider {
    var locationData: [[String:Any]] { get set }
    var locationArray: [UIImage!] { get set }
    init(locationData: [[String:Any]], locationArray: [UIImage!])
    
    func provideImage(completion: UIImage? -> Void)
    func provideImage(atIndex index: Int, completion: UIImage? -> Void)
}