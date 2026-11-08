import SwiftUI
import MapKit

struct AdminMapView: UIViewRepresentable {
    var people: [Person]
    var school: Geofence?
    var home: Geofence?
    @Binding var center: CLLocationCoordinate2D

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.styles.removeAll()
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        var points: [CLLocationCoordinate2D] = []
        for person in people {
            guard let location = person.lastLocation else { continue }
            let coordinate = CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
            points.append(coordinate)
            let annotation = PersonAnnotation(coordinate: coordinate, title: person.name,
                                              subtitle: person.sharing ? "Live" : "Last known")
            map.addAnnotation(annotation)
        }

        if let school {
            addCircle(map, context, center: CLLocationCoordinate2D(latitude: school.lat, longitude: school.lng),
                      radius: max(school.radiusM, 100),
                      stroke: UIColor(red: 0.96, green: 0.72, blue: 0.25, alpha: 1),
                      fill: UIColor(red: 0.96, green: 0.72, blue: 0.25, alpha: 0.10),
                      dashed: false)
            points.append(CLLocationCoordinate2D(latitude: school.lat, longitude: school.lng))
        }

        if let home {
            addCircle(map, context, center: CLLocationCoordinate2D(latitude: home.lat, longitude: home.lng),
                      radius: max(home.radiusM, 100),
                      stroke: UIColor(red: 0.18, green: 0.88, blue: 0.78, alpha: 1),
                      fill: UIColor(red: 0.18, green: 0.88, blue: 0.78, alpha: 0.08),
                      dashed: false)
            points.append(CLLocationCoordinate2D(latitude: home.lat, longitude: home.lng))

            if home.autoWorkMiles > 0 {
                addCircle(map, context, center: CLLocationCoordinate2D(latitude: home.lat, longitude: home.lng),
                          radius: home.autoWorkMiles * 1609.344,
                          stroke: UIColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 1),
                          fill: UIColor(red: 0.98, green: 0.80, blue: 0.08, alpha: 0.035),
                          dashed: true)
                points.append(CLLocationCoordinate2D(latitude: home.lat, longitude: home.lng))
            }
        }

        if !context.coordinator.didFit, !points.isEmpty {
            context.coordinator.didFit = true
            map.setRegion(MKCoordinateRegion(coordinates: points), animated: false)
        }
    }

    private func addCircle(_ map: MKMapView, _ context: Context,
                           center: CLLocationCoordinate2D, radius: CLLocationDistance,
                           stroke: UIColor, fill: UIColor, dashed: Bool) {
        let circle = MKCircle(center: center, radius: radius)
        context.coordinator.styles[ObjectIdentifier(circle)] =
            FenceStyle(stroke: stroke, fill: fill, dashed: dashed)
        map.addOverlay(circle)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminMapView
        var didFit = false
        var styles: [ObjectIdentifier: FenceStyle] = [:]

        init(_ parent: AdminMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PersonAnnotation else { return nil }
            let id = "person"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.markerTintColor = .systemTeal
            view.glyphImage = UIImage(systemName: "person.fill")
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let style = styles[ObjectIdentifier(circle)]
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = style?.stroke ?? .systemTeal
            renderer.fillColor = style?.fill ?? UIColor.systemTeal.withAlphaComponent(0.08)
            renderer.lineWidth = 2
            if style?.dashed == true {
                renderer.lineDashPattern = [8, 7]
            }
            return renderer
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.center = mapView.centerCoordinate
        }
    }
}

struct FenceStyle {
    let stroke: UIColor
    let fill: UIColor
    let dashed: Bool
}

final class PersonAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}

private extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard let first = coordinates.first else {
            self = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                                      latitudinalMeters: 4_000_000,
                                      longitudinalMeters: 4_000_000)
            return
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for point in coordinates {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLng = min(minLng, point.longitude)
            maxLng = max(maxLng, point.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                                    longitudeDelta: max((maxLng - minLng) * 1.5, 0.01))
        self = MKCoordinateRegion(center: center, span: span)
    }
}
