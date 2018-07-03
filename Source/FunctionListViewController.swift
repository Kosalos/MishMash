import UIKit

var functionIndex:Int = 0

let varisNames = [ "Linear", "Sinusoidal", "Spherical", "Swirl", "Horseshoe", "Polar",
                   "Hankerchief", "Heart", "Disc", "Spiral", "Hyperbolic", "Diamond", "Ex",
                   "Julia", "JuliaN", "Bent", "Waves", "Fisheye", "Popcorn", "Power", "Rings", "Fan",
                   "Eyefish", "Bubble", "Cylinder", "Tangent", "Cross", "Noise", "Blur", "Square" ]

class FunctionListViewController: UIViewController,UITableViewDataSource, UITableViewDelegate {
    @IBOutlet var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 25
        
        let path = IndexPath(row: functionIndex, section: 0)
        tableView.selectRow(at: path, animated: false, scrollPosition: .top)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return varisNames.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FLCell", for: indexPath)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .darkGray
        cell.selectedBackgroundView = backgroundView
        
        cell.textLabel?.textColor = .white
        cell.textLabel?.text = varisNames[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        functionIndex = indexPath.row
        self.dismiss(animated: false, completion: { ()->Void in vc.functionNameChanged() })
    }
}
