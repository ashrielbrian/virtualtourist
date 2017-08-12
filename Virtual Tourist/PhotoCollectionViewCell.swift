//
//  PhotoCollectionViewCell.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 09/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var photoImage: UIImageView!

    @IBOutlet weak var photoActivityIndicator: UIActivityIndicatorView!
    
    func showActivityIndicator() {
        performUIUpdatesOnMain {
            self.photoActivityIndicator.startAnimating()
            self.photoActivityIndicator.hidesWhenStopped = true
            self.photoActivityIndicator.center = self.contentView.center
        }
        
        UIApplication.shared.beginIgnoringInteractionEvents()
    }
    
    func hideActivityIndicator() {
        photoActivityIndicator.stopAnimating()
        UIApplication.shared.endIgnoringInteractionEvents()
    }
}
