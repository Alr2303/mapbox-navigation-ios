import Foundation
#if canImport(CarPlay)
import CarPlay

@available(iOS 12.0, *)
public class CarPlayMapViewController: UIViewController {
    
    static let defaultAltitude: CLLocationDistance = 850
    
    var styleManager: StyleManager?
    
    /**
     The interface styles available to `styleManager` for display.
     */
    var styles: [Style] {
        didSet {
            styleManager?.styles = styles
        }
    }
    
    /// A very coarse location manager used for distinguishing between daytime and nighttime.
    fileprivate let coarseLocationManager: CLLocationManager = {
        let coarseLocationManager = CLLocationManager()
        coarseLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return coarseLocationManager
    }()
    
    var isOverviewingRoutes: Bool = false
    
    var mapView: NavigationMapView {
        get {
            return self.view as! NavigationMapView
        }
    }
    
    /**
     The map button for recentering the map view if a user action causes it to stop following the user.
     */
    @objc public lazy var recenterButton: CPMapButton = {
        let recenter = CPMapButton { [weak self] button in
            
            self?.mapView.setUserTrackingMode(.followWithCourse, animated: true)
            button.isHidden = true
        }
        let bundle = Bundle.mapboxNavigation
        recenter.image = UIImage(named: "carplay_locate", in: bundle, compatibleWith: traitCollection)
        return recenter
    }()
    
    /**
     The map button for zooming in the current map view.
     */
    @objc public lazy var zoomInButton: CPMapButton = {
        let zoomInButton = CPMapButton { [weak self] (button) in
            let zoomLevel = self?.mapView.zoomLevel ?? 0
            self?.mapView.setZoomLevel(zoomLevel + 1, animated: true)
        }
        let bundle = Bundle.mapboxNavigation
        zoomInButton.image = UIImage(named: "carplay_plus", in: bundle, compatibleWith: traitCollection)
        return zoomInButton
    }()
    
    /**
     The map button for zooming out the current map view.
     */
    @objc public lazy var zoomOutButton: CPMapButton = {
        let zoomInOut = CPMapButton { [weak self] (button) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.mapView.setZoomLevel(strongSelf.mapView.zoomLevel - 1, animated: true)
        }
        let bundle = Bundle.mapboxNavigation
        zoomInOut.image = UIImage(named: "carplay_minus", in: bundle, compatibleWith: traitCollection)
        return zoomInOut
    }()
    
    /**
     The map button property for hiding or showing the pan map button.
     */
    @objc private(set) public var panMapButton: CPMapButton?
    
    var styleObservation: NSKeyValueObservation?
    
    /**
     Initializes a new CarPlay map view controller.
     
     - parameter styles: The interface styles initially available to the style manager for display.
     */
    required init(styles: [Style]) {
        self.styles = styles
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let styles = aDecoder.decodeObject(of: [NSArray.self, Style.self], forKey: "styles") as? [Style] else {
            return nil
        }
        self.styles = styles
        
        super.init(coder: aDecoder)
    }
    
    override public func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        
        aCoder.encode(styles, forKey: "styles")
    }
    
    override public func loadView() {
        let mapView = NavigationMapView()
//        mapView.navigationMapDelegate = self
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        styleObservation = mapView.observe(\.style, options: .new) { (mapView, change) in
            guard change.newValue != nil else {
                return
            }
            mapView.localizeLabels()
        }
        
        self.view = mapView
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        styleManager = StyleManager()
        styleManager!.delegate = self
        styleManager!.styles = styles
        
        resetCamera(animated: false, altitude: CarPlayMapViewController.defaultAltitude)
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        styleObservation = nil
    }
    
    /**
     Creates a new pan map button for the CarPlay map view controller.
     
     - parameter mapTemplate: The map template available to the pan map button for display.
     */
    @discardableResult public func createPanMapButton(for mapTemplate: CPMapTemplate) -> CPMapButton {
        let panButton = CPMapButton { _ in
            if !mapTemplate.isPanningInterfaceVisible {
                mapTemplate.showPanningInterface(animated: true)
            }
        }
        
        let bundle = Bundle.mapboxNavigation
        panButton.image = UIImage(named: "carplay_pan", in: bundle, compatibleWith: traitCollection)
        self.panMapButton = panButton
        
        return panButton
    }
    
    func resetCamera(animated: Bool = false, altitude: CLLocationDistance? = nil) {
        let camera = mapView.camera
        if let altitude = altitude {
            camera.altitude = altitude
        }
        camera.pitch = 60
        mapView.setCamera(camera, animated: animated)

    }
    
    override public func viewSafeAreaInsetsDidChange() {
        mapView.setContentInset(mapView.safeArea, animated: false)
        
        guard isOverviewingRoutes else {
            super.viewSafeAreaInsetsDidChange()
            return
        }
        
        
        guard let routes = mapView.routes,
            let active = routes.first else {
                super.viewSafeAreaInsetsDidChange()
                return
        }
        
        mapView.fit(to: active, animated: false)
    }
}

@available(iOS 12.0, *)
extension CarPlayMapViewController: StyleManagerDelegate {
    public func location(for styleManager: StyleManager) -> CLLocation? {
        return mapView.userLocationForCourseTracking ?? mapView.userLocation?.location ?? coarseLocationManager.location
    }
    
    func styleManager(_ styleManager: StyleManager, didApply style: Style) {
        let styleURL = style.previewMapStyleURL
        if mapView.styleURL != styleURL {
            mapView.style?.transition = MGLTransition(duration: 0.5, delay: 0)
            mapView.styleURL = styleURL
        }
    }
    
    func styleManagerDidRefreshAppearance(_ styleManager: StyleManager) {
        mapView.reloadStyle(self)
    }
}
#endif

