
"use client";

import React, { useState, useEffect } from 'react';
import { 
  MapPin, Plus, Loader2, DownloadCloud, AlertCircle, Building, Trash2 
} from 'lucide-react';
import { apiFetch } from '../../components/api'; 
import { SectionHeader } from '../../components/SharedUI'; 

// Embedded raw Mapbox data for bulk import
const DEFAULT_MAPBOX_DATA = {
    "type": "FeatureCollection",
    "features": [
        { "type": "Feature", "properties": { "name": "Tsalanang G", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.866129, -26.715188 ] } },
        { "type": "Feature", "properties": { "name": "Tsalanang F", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.866117, -26.715365 ] } },
        { "type": "Feature", "properties": {}, "geometry": { "type": "Point", "coordinates": [ 27.866454, -26.71532 ] } },
        { "type": "Feature", "properties": { "name": "Tsalanang D", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.866156, -26.715586 ] } },
        { "type": "Feature", "properties": { "name": "Leseding E", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.865808, -26.715458 ] } },
        { "type": "Feature", "properties": { "name": "Student Town Laundry ", "marker-symbol": "laundry", "marker-size": "large" }, "geometry": { "type": "Point", "coordinates": [ 27.866671, -26.715819 ] } },
        { "type": "Feature", "properties": { "name": "Vut Main res Gym", "marker-color": "rgba(34, 34, 227, 1)", "marker-symbol": "fitness-centre", "marker-size": "large" }, "geometry": { "type": "Point", "coordinates": [ 27.866418, -26.71565 ] } },
        { "type": "Feature", "properties": { "name": "Lethabong M" }, "geometry": { "type": "Point", "coordinates": [ 27.867029, -26.715623 ] } },
        { "type": "Feature", "properties": { "name": "" }, "geometry": { "type": "Point", "coordinates": [ 27.867072, -26.715809 ] } },
        { "type": "Feature", "properties": { "name": "Lethabong L" }, "geometry": { "type": "Point", "coordinates": [ 27.867075, -26.715972 ] } },
        { "type": "Feature", "properties": { "name": "Leseding A", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.865982, -26.715822 ] } },
        { "type": "Feature", "properties": { "name": "Leseding B", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.865654, -26.71584 ] } },
        { "type": "Feature", "properties": { "name": "Leseding C", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.865667, -26.715647 ] } },
        { "type": "Feature", "properties": { "name": "Placement Office", "marker-symbol": "home", "marker-size": "large" }, "geometry": { "type": "Point", "coordinates": [ 27.86461, -26.716297 ] } },
        { "type": "Feature", "properties": { "name": "Student Town Matron", "marker-color": "#312E81", "marker-size": "large", "marker-symbol": "commercial" }, "geometry": { "type": "Point", "coordinates": [ 27.86673, -26.715923 ] } },
        { "type": "Feature", "properties": {}, "geometry": { "type": "Polygon", "coordinates": [ [ [ 27.865453, -26.716058 ], [ 27.865453, -26.716058 ], [ 27.865453, -26.716058 ], [ 27.865453, -26.716058 ] ] ] } },
        { "type": "Feature", "properties": { "name": "Main res Basket Ball Court", "fill-opacity": 0.5, "fill": "rgba(222, 195, 220, 1)" }, "geometry": { "type": "Polygon", "coordinates": [ [ [ 27.865466, -26.716058 ], [ 27.865466, -26.716626 ], [ 27.866392, -26.716626 ], [ 27.866392, -26.716058 ], [ 27.865466, -26.716058 ] ] ] } },
        { "type": "Feature", "properties": { "name": "Vut Main res Tennis court", "stroke": "#312E81", "fill-opacity": 0.3 }, "geometry": { "type": "Polygon", "coordinates": [ [ [ 27.863297, -26.715395 ], [ 27.863297, -26.715754 ], [ 27.863894, -26.715754 ], [ 27.863894, -26.715395 ], [ 27.863297, -26.715395 ] ] ] } },
        { "type": "Feature", "properties": { "name": "Vut Chapel", "marker-symbol": "religious-christian", "marker-size": "large", "marker-color": "#312E81" }, "geometry": { "type": "Point", "coordinates": [ 27.865702, -26.714708 ] } },
        { "type": "Feature", "properties": { "name": "Main Res Lapa" }, "geometry": { "type": "Point", "coordinates": [ 27.865465, -26.714222 ] } },
        { "type": "Feature", "properties": { "name": "Vut Cafeteria", "marker-symbol": "fast-food", "marker-size": "large" }, "geometry": { "type": "Point", "coordinates": [ 27.864863, -26.716629 ] } },
        { "type": "Feature", "properties": { "name": "Vut res soccer field", "stroke": "#312E81", "stroke-opacity": 1 }, "geometry": { "type": "LineString", "coordinates": [ [ 27.862851, -26.714086 ], [ 27.862591, -26.713614 ], [ 27.86295, -26.713587 ], [ 27.863319, -26.713632 ], [ 27.863549, -26.714157 ], [ 27.863708, -26.71438 ], [ 27.863838, -26.714727 ], [ 27.863918, -26.714995 ], [ 27.863698, -26.715155 ], [ 27.863429, -26.715182 ], [ 27.863299, -26.715128 ], [ 27.86319, -26.714932 ], [ 27.86304, -26.714576 ], [ 27.86296, -26.714318 ], [ 27.862861, -26.714104 ], [ 27.862761, -26.713908 ], [ 27.862731, -26.713952 ] ] } },
        { "type": "Feature", "properties": { "name": "Student Town soccer field", "stroke-width": 4 }, "geometry": { "type": "LineString", "coordinates": [ [ 27.867454, -26.71622 ], [ 27.867581, -26.716258 ], [ 27.867678, -26.716266 ], [ 27.86776, -26.716262 ], [ 27.867831, -26.716233 ], [ 27.867918, -26.716181 ], [ 27.867874, -26.715987 ], [ 27.867758, -26.715897 ], [ 27.867613, -26.715858 ], [ 27.86741, -26.715884 ], [ 27.867367, -26.715922 ], [ 27.867352, -26.716013 ], [ 27.86737, -26.716126 ], [ 27.867453, -26.716217 ] ] } },
        { "type": "Feature", "properties": { "marker-size": "large", "marker-symbol": "laundry", "marker-color": "#312E81", "name": "Dinaleding Res Laundry " }, "geometry": { "type": "Point", "coordinates": [ 27.865917, -26.717674 ] } }
    ]
};

export default function CampusLocationsManager() {
    const [locations, setLocations] = useState<any[]>([]);
    const [loading, setLoading] = useState(false);
    const [importing, setImporting] = useState(false);
    
    const [formData, setFormData] = useState({
        name: '',
        description: '',
        latitude: '',
        longitude: '',
        location_type: 'VENUE'
    });

    const fetchLocations = async () => {
        setLoading(true);
        try {
            const response = await apiFetch(`/campus-locations/`);
            setLocations(response.results || response || []);
        } catch (error) {
            console.error("Failed to fetch locations:", error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchLocations();
    }, []);

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleManualAdd = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        try {
            await apiFetch('/campus-locations/', {
                method: 'POST',
                body: JSON.stringify({
                    ...formData,
                    latitude: parseFloat(formData.latitude),
                    longitude: parseFloat(formData.longitude)
                })
            });
            setFormData({ name: '', description: '', latitude: '', longitude: '', location_type: 'VENUE' });
            fetchLocations();
        } catch (error) {
            alert("Failed to add location. Check coordinates format.");
        } finally {
            setLoading(false);
        }
    };

    const extractCoordinates = (geometry: any) => {
        if (geometry.type === 'Point') {
            return { lng: geometry.coordinates[0], lat: geometry.coordinates[1] };
        } else if (geometry.type === 'LineString') {
            return { lng: geometry.coordinates[0][0], lat: geometry.coordinates[0][1] };
        } else if (geometry.type === 'Polygon') {
            return { lng: geometry.coordinates[0][0][0], lat: geometry.coordinates[0][0][1] };
        }
        return { lng: 0, lat: 0 };
    };

    const handleBulkImport = async () => {
        if (!confirm("This will import all embedded Mapbox data. Proceed?")) return;
        setImporting(true);
        let successCount = 0;

        for (const feature of DEFAULT_MAPBOX_DATA.features) {
            const { lat, lng } = extractCoordinates(feature.geometry);
            const name = feature.properties.name?.trim() || "Unnamed Map Node";
            
            try {
                await apiFetch('/campus-locations/', {
                    method: 'POST',
                    body: JSON.stringify({
                        name: name,
                        description: `Imported from MapBox: ${feature.geometry.type}`,
                        latitude: lat,
                        longitude: lng,
                        location_type: 'VENUE'
                    })
                });
                successCount++;
            } catch (err) {
                console.error("Failed to import node:", name);
            }
        }
        
        alert(`Successfully imported ${successCount} locations.`);
        setImporting(false);
        fetchLocations();
    };

    const handleDelete = async (id: string) => {
        if (!confirm("Remove this location marker from the database?")) return;
        try {
            await apiFetch(`/campus-locations/${id}/`, { method: 'DELETE' });
            fetchLocations();
        } catch (err) {
            console.error(err);
            alert("Delete failed.");
        }
    };

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500 max-w-6xl mx-auto">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <SectionHeader title="Campus Map Integration" />
                    <p className="text-slate-400 text-[10px] font-black uppercase tracking-widest mt-1">
                        Active Navigational Nodes: {locations.length}
                    </p>
                </div>
                
                <button 
                    onClick={handleBulkImport}
                    disabled={importing}
                    className="flex items-center gap-2 bg-indigo-50 border border-indigo-200 text-indigo-700 px-6 py-3 rounded-2xl text-sm font-bold shadow-sm hover:bg-indigo-100 transition-all disabled:opacity-50"
                >
                    {importing ? <Loader2 size={16} className="animate-spin" /> : <DownloadCloud size={16} />}
                    {importing ? "Importing Data..." : "Bulk Import Mapbox Data"}
                </button>
            </div>

            <div className="bg-blue-50 border border-blue-100 p-4 rounded-2xl flex items-start gap-4 shadow-sm">
                <AlertCircle className="text-blue-500 shrink-0 mt-0.5" size={20} />
                <div>
                    <h3 className="text-blue-700 text-xs font-black uppercase tracking-widest">Mobile Map System</h3>
                    <p className="text-blue-600/80 text-sm font-medium mt-1">
                        Points added here instantly appear as pins on the student and staff mobile maps. They are used for directions and plotting emergencies.
                    </p>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Manual Add Form */}
                <div className="bg-white border border-slate-200 p-6 rounded-[28px] shadow-sm lg:col-span-1 h-fit">
                    <h3 className="text-sm font-black text-slate-800 uppercase tracking-widest mb-6 flex items-center gap-2">
                        <MapPin size={18} className="text-red-500" /> Add Custom Node
                    </h3>
                    
                    <form onSubmit={handleManualAdd} className="space-y-4">
                        <div>
                            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest ml-1">Location Name</label>
                            <input required type="text" name="name" value={formData.name} onChange={handleInputChange} placeholder="e.g. Main Gate" className="mt-1 w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl text-sm outline-none focus:bg-white focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all font-medium text-slate-700" />
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <div>
                                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest ml-1">Latitude</label>
                                <input required type="number" step="any" name="latitude" value={formData.latitude} onChange={handleInputChange} placeholder="-26.715" className="mt-1 w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl text-sm outline-none focus:bg-white focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all font-medium text-slate-700" />
                            </div>
                            <div>
                                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest ml-1">Longitude</label>
                                <input required type="number" step="any" name="longitude" value={formData.longitude} onChange={handleInputChange} placeholder="27.866" className="mt-1 w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl text-sm outline-none focus:bg-white focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all font-medium text-slate-700" />
                            </div>
                        </div>
                        <div>
                            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest ml-1">Category Type</label>
                            <select name="location_type" value={formData.location_type} onChange={handleInputChange} className="mt-1 w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl text-sm outline-none focus:bg-white focus:border-red-400 focus:ring-4 focus:ring-red-50 transition-all font-medium text-slate-700">
                                <option value="VENUE">Standard Venue / Building</option>
                                <option value="LAUNDRY">Laundry Facility</option>
                                <option value="GATE">Security Gate</option>
                                <option value="GYM">Gym / Sports</option>
                            </select>
                        </div>
                        <button type="submit" disabled={loading} className="w-full mt-4 flex items-center justify-center gap-2 bg-slate-900 text-white px-6 py-4 rounded-xl text-sm font-bold shadow-md hover:bg-slate-800 transition-all disabled:opacity-50">
                            {loading ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
                            SAVE TO DATABASE
                        </button>
                    </form>
                </div>

                {/* List View */}
                <div className="bg-white border border-slate-200 rounded-[28px] shadow-sm lg:col-span-2 overflow-hidden flex flex-col">
                    <div className="p-6 border-b border-slate-100 flex items-center justify-between">
                        <h3 className="text-sm font-black text-slate-800 uppercase tracking-widest flex items-center gap-2">
                            <Building size={18} className="text-slate-400" /> Database Map Nodes
                        </h3>
                    </div>
                    
                    <div className="overflow-y-auto max-h-[600px] custom-scrollbar p-2">
                        {locations.length === 0 ? (
                            <div className="p-12 text-center text-slate-400 font-bold text-sm tracking-widest uppercase">No locations mapped yet.</div>
                        ) : (
                            <div className="space-y-2">
                                {locations.map(loc => (
                                    <div key={loc.id} className="p-4 border border-slate-100 rounded-2xl flex items-center justify-between hover:bg-slate-50 transition-all">
                                        <div className="flex items-center gap-4">
                                            <div className="h-10 w-10 bg-indigo-50 text-indigo-500 rounded-xl flex items-center justify-center shrink-0">
                                                <MapPin size={18} />
                                            </div>
                                            <div>
                                                <h4 className="font-bold text-slate-800">{loc.name}</h4>
                                                <p className="text-[10px] text-slate-400 font-bold uppercase tracking-widest mt-0.5">
                                                    Lat: {Number(loc.latitude).toFixed(5)} • Lng: {Number(loc.longitude).toFixed(5)} • {loc.location_type}
                                                </p>
                                            </div>
                                        </div>
                                        <button 
                                            onClick={() => handleDelete(loc.id)}
                                            className="p-2.5 text-red-400 hover:text-white hover:bg-red-500 rounded-lg transition-all"
                                        >
                                            <Trash2 size={16} />
                                        </button>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}