//
//  EmptyPastureTableViewCell.swift
//  Myra
//
//  Created by Amir Shayegh on 2018-10-22.
//  Copyright © 2018 Government of British Columbia. All rights reserved.
//

import UIKit

class EmptyPastureTableViewCell: UITableViewCell, Theme {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var container: UIView!
    override func awakeFromNib() {
        super.awakeFromNib()
        style()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func style() {
        styleSubHeader(label: label)
        styleContainer(view: container)
    }
    
}
