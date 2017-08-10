//
//  GCDBlackBox.swift
//  Virtual Tourist
//
//  Created by Ashriel Brian Tang on 09/08/2017.
//  Copyright © 2017 Udacity. All rights reserved.
//

import Foundation

func performUIUpdatesOnMain(_ updates: @escaping () -> Void) {
    DispatchQueue.main.async {
        updates()
    }
}
