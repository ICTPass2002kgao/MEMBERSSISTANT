"use client";

import React, { useState, useEffect } from 'react';
import { Building2, Plus, ArrowLeft, Loader2, Settings, Users, Search, Layers, Wand2, Trash2, CheckCircle2, BedDouble, User as UserIcon, ArrowUpToLine, Copy } from 'lucide-react';
import { apiFetch, BASE_URL } from '../../components/api';
import { SectionHeader, ModalWrapper, Input, Select, SubmitButton } from '../../components/SharedUI';

export default function AccommodationsPage() {
    const [accommodations, setAccommodations] = useState<any[]>([]);
    const [blocks, setBlocks] = useState<any[]>([]);
    const [units, setUnits] = useState<any[]>([]); 
    const [rooms, setRooms] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    
    const [selectedAccommodation, setSelectedAccommodation] = useState<any | null>(null);
    const [isAccModalOpen, setIsAccModalOpen] = useState(false);
    const [editingAcc, setEditingAcc] = useState<any | null>(null);
    const [isMasterBuilderOpen, setIsMasterBuilderOpen] = useState(false);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [aData, bData, uData, rData] = await Promise.all([
                apiFetch('/accommodations/'), apiFetch('/blocks/'), apiFetch('/units/'), apiFetch('/rooms/')
            ]);
            setAccommodations(aData.results || aData || []);
            setBlocks(bData.results || bData || []);
            setUnits(uData.results || uData || []); 
            setRooms(rData.results || rData || []);
        } catch (err) { console.error(err); } finally { setLoading(false); }
    };

    useEffect(() => { fetchData(); }, []);

    const handleAccommodationSuccess = (accData: any, isEdit: boolean) => {
        setIsAccModalOpen(false);
        fetchData();
        if (!isEdit && accData && accData.id) {
            setSelectedAccommodation(accData);
            setTimeout(() => setIsMasterBuilderOpen(true), 300);
        }
    };

    if (loading) return <div className="py-20 flex justify-center"><Loader2 className="animate-spin text-blue-500" size={40} /></div>;

    if (!selectedAccommodation) {
        return (
            <div className="space-y-6 animate-in fade-in duration-300">
                <div className="flex justify-between items-center mb-8">
                    <SectionHeader title="Property Portfolio" />
                    <button onClick={() => { setEditingAcc(null); setIsAccModalOpen(true); }} className="flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white rounded-xl text-xs font-bold shadow-md hover:bg-blue-700">
                        <Plus size={16} /> ADD PROPERTY
                    </button>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                    {accommodations.map((acc: any) => (
                        <div key={acc.id} onClick={() => setSelectedAccommodation(acc)} className="bg-white border border-blue-100 rounded-[32px] p-8 shadow-sm hover:shadow-md cursor-pointer transition-all">
                            <div className="flex justify-between items-start mb-6">
                                <div className="p-4 bg-blue-50 rounded-2xl">
                                    {acc.accommodation_logo_url ? (
                                        <img src={acc.accommodation_logo_url} alt="Logo" className="w-7 h-7 object-cover rounded-md" />
                                    ) : (
                                        <Building2 className="text-blue-600" size={28} />
                                    )}
                                </div>
                                <span className="text-[10px] font-black uppercase tracking-widest px-3 py-1 bg-slate-100 rounded-lg">{acc.gender_target}</span>
                            </div>
                            <h4 className="font-black text-xl text-blue-950 mb-1">{acc.name}</h4>
                            <p className="text-xs text-slate-400 mb-6">{acc.address}</p>
                            <div className="flex justify-between text-[10px] font-bold text-blue-600 border-t pt-4">
                                <span>{blocks.filter(b => b.accommodation === acc.id).length} BLOCKS</span>
                                <span>MANAGE &rarr;</span>
                            </div>
                        </div>
                    ))}
                </div>
                {isAccModalOpen && <AccommodationModal initialData={editingAcc} onClose={() => setIsAccModalOpen(false)} onSuccess={handleAccommodationSuccess} />}
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-in slide-in-from-right-4 duration-300">
            <button onClick={() => setSelectedAccommodation(null)} className="flex items-center gap-2 text-[10px] font-bold text-slate-400 uppercase tracking-widest"><ArrowLeft size={14} /> BACK</button>
            
            <div className="bg-white p-8 rounded-[32px] shadow-sm border border-blue-50 flex justify-between items-center flex-wrap gap-4">
                <div className="flex items-center gap-4">
                    {selectedAccommodation.accommodation_logo_url && (
                        <img src={selectedAccommodation.accommodation_logo_url} alt="Logo" className="w-14 h-14 object-cover rounded-xl shadow-sm border border-slate-100" />
                    )}
                    <div>
                        <h2 className="text-3xl font-black text-blue-950">{selectedAccommodation.name}</h2>
                        <p className="text-sm text-slate-500 mt-1">{selectedAccommodation.address}</p>
                    </div>
                </div>
                <div className="flex gap-3">
                    <button onClick={() => setIsMasterBuilderOpen(true)} className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl text-xs font-black shadow-lg shadow-blue-500/30 hover:shadow-xl transition-all hover:-translate-y-0.5">
                        <Wand2 size={16} /> MASTER BUILDER
                    </button>
                    <button onClick={() => { setEditingAcc(selectedAccommodation); setIsAccModalOpen(true); }} className="p-3 bg-slate-50 text-slate-600 rounded-xl hover:bg-slate-100"><Settings size={20} /></button>
                </div>
            </div>

            <div className="space-y-6">
                {blocks.filter(b => b.accommodation === selectedAccommodation.id).length === 0 && (
                    <div className="text-center py-20 bg-slate-50 rounded-3xl border border-dashed border-slate-200">
                        <Wand2 className="mx-auto text-slate-300 mb-4" size={48} />
                        <h3 className="text-lg font-black text-slate-700">No Blocks Found</h3>
                        <p className="text-sm text-slate-500 mt-2">Click "Master Builder" to quickly generate multi-floor blocks and rooms.</p>
                    </div>
                )}

                {blocks.filter(b => b.accommodation === selectedAccommodation.id).map(block => {
                    const blockRooms = rooms.filter(r => r.block === block.id);
                    const occupiedCount = blockRooms.filter(r => r.is_occupied).length;

                    return (
                        <div key={block.id} className="bg-white border border-blue-100 rounded-3xl p-8 flex flex-col md:flex-row justify-between items-center gap-6">
                            <div className="flex items-center gap-6">
                                <div className="w-16 h-16 bg-blue-50 rounded-2xl flex items-center justify-center text-blue-600 font-black text-xl">{block.name.charAt(0)}</div>
                                <div>
                                    <h4 className="font-black text-xl text-blue-950">{block.name}</h4>
                                    <div className="flex gap-2 mt-1">
                                        <span className="text-[10px] font-bold px-2 py-0.5 bg-slate-100 rounded uppercase">{block.gender_target}</span>
                                    </div>
                                </div>
                            </div>

                            <div className="flex gap-8 border-l border-r px-8 border-blue-50">
                                <div className="text-center">
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Total Rooms</p>
                                    <p className="text-lg font-black text-blue-950">{blockRooms.length}</p>
                                </div>
                                <div className="text-center">
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Occupied</p>
                                    <p className="text-lg font-black text-rose-600">{occupiedCount}</p>
                                </div>
                                <div className="text-center">
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Vacant</p>
                                    <p className="text-lg font-black text-emerald-600">{blockRooms.length - occupiedCount}</p>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>

            {isAccModalOpen && <AccommodationModal initialData={editingAcc} onClose={() => setIsAccModalOpen(false)} onSuccess={handleAccommodationSuccess} />}
            {isMasterBuilderOpen && <MasterBuilderModal accommodation={selectedAccommodation} onClose={() => setIsMasterBuilderOpen(false)} onSuccess={() => { setIsMasterBuilderOpen(false); fetchData(); }} />}
        </div>
    );
}

// ============================================================================
// THE MASTER BUILDER MODAL (MULTI-FLOOR + INTERACTIVE MATRIX)
// ============================================================================

function MasterBuilderModal({ accommodation, onClose, onSuccess }: any) {
    const [blueprintQueue, setBlueprintQueue] = useState<any[]>([]);
    const [isDeploying, setIsDeploying] = useState(false);
    const [deployStatus, setDeployStatus] = useState("");

    // --- 1. BLOCK CONFIGURATION ---
    const [baseBlockName, setBaseBlockName] = useState("Lethabong");
    const [genderTarget, setGenderTarget] = useState(accommodation.gender_target || "MIXED");
    
    const [suffixInputType, setSuffixInputType] = useState("custom"); 
    const [customSuffixes, setCustomSuffixes] = useState("L, M, P");
    const [suffixStart, setSuffixStart] = useState("A");
    const [suffixEnd, setSuffixEnd] = useState("D");
    const [suffixExclude, setSuffixExclude] = useState("");

    // --- 2. MULTI-FLOOR ROOM CONFIGURATION ---
    const [floorStart, setFloorStart] = useState("0"); 
    const [floorEnd, setFloorEnd] = useState("2");   
    const [combineNames, setCombineNames] = useState("yes"); 
    
    // Per-Floor Configuration State
    const [floorConfigs, setFloorConfigs] = useState<{ floor: string, start: string, end: string }[]>([
        { floor: "0", start: "01", end: "05" },
        { floor: "1", start: "01", end: "05" },
        { floor: "2", start: "01", end: "05" }
    ]);

    // --- 3. INTERACTIVE MATRIX STATE ---
    const [globalSharing, setGlobalSharing] = useState("no"); 
    const [bedsPerSharedRoom, setBedsPerSharedRoom] = useState(2);
    const [sharingOverrides, setSharingOverrides] = useState<Record<string, boolean>>({});

    useEffect(() => { setSharingOverrides({}); }, [globalSharing]);

    // --- HELPER FUNCTIONS ---
    const handleBlockNameChange = (val: string) => {
        // Auto Capitalize First Letter
        setBaseBlockName(val.charAt(0).toUpperCase() + val.slice(1));
    };

    const handleFloorRangeUpdate = (startVal: string, endVal: string) => {
        setFloorStart(startVal);
        setFloorEnd(endVal);

        const sNum = parseInt(startVal);
        const eNum = parseInt(endVal);

        if (!isNaN(sNum) && !isNaN(eNum) && sNum <= eNum) {
            const newConfigs = [];
            for (let i = sNum; i <= eNum; i++) {
                const existing = floorConfigs.find(c => c.floor === i.toString());
                newConfigs.push(existing ? existing : { floor: i.toString(), start: "01", end: "05" });
            }
            setFloorConfigs(newConfigs);
        }
    };

    const updateFloorConfig = (index: number, field: 'start' | 'end', value: string) => {
        const updated = [...floorConfigs];
        updated[index][field] = value;
        setFloorConfigs(updated);
    };

    const copyFromAbove = (index: number) => {
        if (index === 0) return;
        const updated = [...floorConfigs];
        updated[index].start = updated[index - 1].start;
        updated[index].end = updated[index - 1].end;
        setFloorConfigs(updated);
    };

    const getSuffixList = () => {
        if (suffixInputType === "custom") {
            return customSuffixes.split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
        }
        
        let result: string[] = [];
        const excludes = suffixExclude.split(',').map(s => s.trim().toUpperCase());
        
        const isNumeric = !isNaN(parseInt(suffixStart)) && !isNaN(parseInt(suffixEnd));
        if (isNumeric) {
            const s = parseInt(suffixStart);
            const e = parseInt(suffixEnd);
            for (let i = s; i <= e; i++) result.push(i.toString());
        } else {
            const s = suffixStart.toUpperCase().charCodeAt(0);
            const e = suffixEnd.toUpperCase().charCodeAt(0);
            for (let i = s; i <= e; i++) result.push(String.fromCharCode(i));
        }

        return result.filter(item => !excludes.includes(item.toUpperCase()));
    };

    const getBaseRoomsList = () => {
        let res: string[] = [];
        floorConfigs.forEach(config => {
            const rStart = parseInt(config.start);
            const rEnd = parseInt(config.end);
            
            if (isNaN(rStart) || isNaN(rEnd) || rStart > rEnd) return;
            
            const padLen = config.start.length;
            for (let r = rStart; r <= rEnd; r++) {
                res.push(`${config.floor}${r.toString().padStart(padLen, '0')}`);
            }
        });
        return res;
    };

    const toggleRoomSharing = (baseRoom: string) => {
        const currentState = sharingOverrides[baseRoom] !== undefined ? sharingOverrides[baseRoom] : (globalSharing === "yes");
        setSharingOverrides({
            ...sharingOverrides,
            [baseRoom]: !currentState
        });
    };

    // --- QUEUE MANAGEMENT ---
    const addToQueue = (e: React.FormEvent) => {
        e.preventDefault();
        
        if (!baseBlockName.trim()) return alert("Please enter a base block name.");
        
        const suffixes = getSuffixList();
        if (suffixes.length === 0) return alert("Configuration resulted in 0 block identifiers.");

        const baseRooms = getBaseRoomsList();
        if (baseRooms.length === 0) return alert("Invalid floor or room range. Ensure rooms have valid start and end numbers.");

        const templateRooms = baseRooms.map(room => {
            return {
                baseNumber: room,
                isShared: sharingOverrides[room] !== undefined ? sharingOverrides[room] : (globalSharing === "yes")
            };
        });

        const totalBlocks = suffixes.length;
        let roomsPerBlock = 0;
        templateRooms.forEach(tr => {
            roomsPerBlock += tr.isShared ? bedsPerSharedRoom : 1;
        });

        const payload = {
            id: Date.now(),
            baseBlockName: baseBlockName.trim(),
            suffixes: suffixes,
            genderTarget: genderTarget,
            templateRooms: templateRooms,
            combineNames: combineNames === "yes",
            bedsPerSharedRoom: bedsPerSharedRoom,
            summary: `${totalBlocks} Blocks generated. ${floorConfigs.length} Floors per block. Each block contains ${roomsPerBlock} individual beds/rooms.`
        };

        setBlueprintQueue([...blueprintQueue, payload]);
        setBaseBlockName("");
    };

    const removeFromQueue = (id: number) => {
        setBlueprintQueue(blueprintQueue.filter(q => q.id !== id));
    };

    // --- DEPLOYMENT EXECUTION ---
    const deployBlueprint = async () => {
        if (blueprintQueue.length === 0) return alert("Staging area is empty. Add a structure first.");
        setIsDeploying(true);

        try {
            for (const item of blueprintQueue) {
                for (const suffix of item.suffixes) {
                    const fullBlockName = `${item.baseBlockName} ${suffix}`.trim();
                    setDeployStatus(`Deploying ${fullBlockName}...`);
                    
                    const blockRes = await apiFetch('/blocks/', {
                        method: 'POST',
                        body: JSON.stringify({ name: fullBlockName, gender_target: item.genderTarget, accommodation: accommodation.id })
                    });
                    
                    let prefix = item.combineNames ? suffix : "";
                    
                    for (const tRoom of item.templateRooms) {
                        let fullRoomName = `${prefix}${tRoom.baseNumber}`;

                        if (tRoom.isShared) {
                            for (let b = 1; b <= item.bedsPerSharedRoom; b++) {
                                await apiFetch('/rooms/', {
                                    method: 'POST',
                                    body: JSON.stringify({ room_number: `${fullRoomName}-${b}`, unit: null, block: blockRes.id })
                                });
                            }
                        } else {
                            await apiFetch('/rooms/', {
                                method: 'POST',
                                body: JSON.stringify({ room_number: fullRoomName, unit: null, block: blockRes.id })
                            });
                        }
                    }
                }
            }
            setDeployStatus("Deployment Complete!");
            setTimeout(() => onSuccess(), 1000);
        } catch (err) {
            console.error(err);
            alert("An error occurred during deployment. Check your network.");
            setIsDeploying(false);
        }
    };

    const baseRooms = getBaseRoomsList();
    const uniqueFloors = Array.from(new Set(floorConfigs.map(c => c.floor)));

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 lg:p-8 bg-blue-950/40 backdrop-blur-sm animate-in fade-in duration-300">
            <div className="bg-white rounded-[32px] shadow-2xl w-full max-w-[1400px] h-full max-h-[90vh] flex flex-col overflow-hidden border border-blue-100/50">
                
                {/* Header */}
                <div className="flex justify-between items-center px-8 py-6 border-b border-slate-100 bg-slate-50/50">
                    <div>
                        <h2 className="text-2xl font-black text-blue-950 flex items-center gap-2"><Wand2 className="text-blue-600"/> Master Blueprint Builder</h2>
                        <p className="text-sm text-slate-500 font-medium">Define your naming structures, customize sharing rules by floor, and deploy at once.</p>
                    </div>
                    {!isDeploying && (
                        <button onClick={onClose} className="p-2 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-xl transition-all"><Trash2 size={24} /></button>
                    )}
                </div>

                {/* Main Content Area */}
                <div className="flex-1 overflow-hidden flex flex-col lg:flex-row bg-white">
                    
                    {/* LEFT COLUMN: THE CONFIGURATION FORM */}
                    <div className="w-full lg:w-1/3 overflow-y-auto p-8 border-r border-slate-100 custom-scrollbar bg-white">
                        <form id="builder-form" onSubmit={addToQueue} className="space-y-8 pr-2">
                            
                            {/* SECTION 1: BLOCK NAMING */}
                            <div className="space-y-4">
                                <h3 className="text-xs font-black text-slate-800 uppercase tracking-widest flex items-center gap-2 border-b pb-2"><Building2 size={16} className="text-blue-500"/> 1. Define Block Names</h3>
                                <Input label="Base Name (e.g. Lethabong, Block)" value={baseBlockName} onChange={(e:any) => handleBlockNameChange(e.target.value)} required />
                                
                                <Select label="How do you identify these blocks?" value={suffixInputType} onChange={(e:any) => setSuffixInputType(e.target.value)}>
                                    <option value="custom">Custom List (e.g. L, M, P)</option>
                                    <option value="range">Range (e.g. A-E, 1-6)</option>
                                </Select>

                                {suffixInputType === 'custom' ? (
                                    <div className="bg-blue-50 p-4 rounded-xl border border-blue-100">
                                        <Input label="Identifiers (Comma separated)" placeholder="L, M, P" value={customSuffixes} onChange={(e:any) => setCustomSuffixes(e.target.value.toUpperCase())} required />
                                    </div>
                                ) : (
                                    <div className="bg-blue-50 p-4 rounded-xl border border-blue-100 space-y-4">
                                        <div className="grid grid-cols-2 gap-4">
                                            <Input label="Start (e.g. A or 1)" value={suffixStart} onChange={(e:any) => setSuffixStart(e.target.value.toUpperCase())} required />
                                            <Input label="End (e.g. E or 6)" value={suffixEnd} onChange={(e:any) => setSuffixEnd(e.target.value.toUpperCase())} required />
                                        </div>
                                        <Input label="Exclude (e.g. C, D)" placeholder="Optional" value={suffixExclude} onChange={(e:any) => setSuffixExclude(e.target.value.toUpperCase())} />
                                    </div>
                                )}
                            </div>

                            {/* SECTION 2: PER-FLOOR CONFIGURATION */}
                            <div className="space-y-4">
                                <h3 className="text-xs font-black text-slate-800 uppercase tracking-widest flex items-center gap-2 border-b pb-2"><Layers size={16} className="text-emerald-500"/> 2. Multi-Floor Ranges</h3>
                                
                                <div className="grid grid-cols-2 gap-4">
                                    <Input type="number" label="Lowest Floor (0 = Ground)" value={floorStart} onChange={(e:any) => handleFloorRangeUpdate(e.target.value, floorEnd)} required />
                                    <Input type="number" label="Highest Floor" value={floorEnd} onChange={(e:any) => handleFloorRangeUpdate(floorStart, e.target.value)} required />
                                </div>
                                <Select label="Combine identifier with room? (L + 001 = L001)" value={combineNames} onChange={(e:any) => setCombineNames(e.target.value)}>
                                    <option value="yes">Yes (Creates L001, M101)</option>
                                    <option value="no">No (Just creates 001, 101)</option>
                                </Select>

                                <div className="mt-4 p-4 bg-emerald-50/50 rounded-xl border border-emerald-100 space-y-3">
                                    <h4 className="text-[10px] font-black text-emerald-800 uppercase tracking-widest mb-2">Configure Per-Floor Ranges</h4>
                                    
                                    <div className="max-h-[250px] overflow-y-auto custom-scrollbar space-y-3 pr-2">
                                        {floorConfigs.map((config, idx) => (
                                            <div key={config.floor} className="flex gap-2 items-end bg-white p-3 rounded-lg border border-emerald-200 shadow-sm">
                                                <div className="w-16 shrink-0 pb-2">
                                                    <span className="text-[10px] font-black text-slate-500 uppercase">Floor {config.floor}</span>
                                                </div>
                                                <div className="flex-1">
                                                    <Input label="Start" value={config.start} onChange={(e:any) => updateFloorConfig(idx, 'start', e.target.value)} required />
                                                </div>
                                                <div className="flex-1">
                                                    <Input label="End" value={config.end} onChange={(e:any) => updateFloorConfig(idx, 'end', e.target.value)} required />
                                                </div>
                                                {idx > 0 && (
                                                    <button 
                                                        type="button" 
                                                        onClick={() => copyFromAbove(idx)} 
                                                        title="Copy range from floor above"
                                                        className="mb-1.5 p-2 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition-colors shrink-0"
                                                    >
                                                        <Copy size={14} />
                                                    </button>
                                                )}
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>

                    {/* MIDDLE COLUMN: INTERACTIVE MATRIX (GROUPED BY FLOOR) */}
                    <div className="w-full lg:w-1/3 overflow-y-auto p-8 border-r border-slate-100 custom-scrollbar bg-slate-50">
                        <div className="mb-6">
                            <h3 className="text-xs font-black text-slate-800 uppercase tracking-widest flex items-center gap-2 border-b pb-2"><UserIcon size={16} className="text-indigo-500"/> 3. Sharing Matrix Setup</h3>
                            <p className="text-xs text-slate-500 mt-2">Click on any specific room below to toggle between single and shared beds.</p>
                        </div>
                        
                        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm mb-6 space-y-4">
                            <Select label="Global Default Pattern" value={globalSharing} onChange={(e:any) => setGlobalSharing(e.target.value)}>
                                <option value="no">All Rooms are Single by Default</option>
                                <option value="yes">All Rooms are Shared by Default</option>
                            </Select>
                            
                                <div className="flex items-center gap-4 border-t pt-4">
                                <span className="text-xs font-bold text-slate-500">If shared, beds per room:</span>
                                <input type="number" className="w-20 px-3 py-1.5 border border-slate-200 rounded-lg text-sm outline-none focus:border-indigo-500" value={bedsPerSharedRoom} onChange={(e:any) => setBedsPerSharedRoom(parseInt(e.target.value) || 2)} min="2" max="10"/>
                            </div>
                        </div>

                        {baseRooms.length > 0 ? (
                            <div className="space-y-6">
                                {uniqueFloors.map(floor => {
                                    // Match rooms specifically for this floor using the floorConfig's pad length logic
                                    const matchingConfig = floorConfigs.find(c => c.floor === floor);
                                    if (!matchingConfig) return null;
                                    const padLength = matchingConfig.start.length;

                                    return (
                                        <div key={floor}>
                                            <div className="flex items-center gap-2 mb-3">
                                                <ArrowUpToLine size={14} className="text-slate-400" />
                                                <h4 className="text-[11px] font-black text-slate-500 uppercase tracking-widest">
                                                    Floor {floor === "0" ? "0 (Ground)" : floor}
                                                </h4>
                                            </div>
                                            <div className="grid grid-cols-2 gap-3">
                                                {baseRooms.filter(r => r.substring(0, r.length - padLength) === floor).map(room => {
                                                    const isShared = sharingOverrides[room] !== undefined ? sharingOverrides[room] : (globalSharing === "yes");
                                                    return (
                                                        <button 
                                                            key={room} type="button"
                                                            onClick={() => toggleRoomSharing(room)}
                                                            className={`p-3 rounded-xl border flex flex-col items-center justify-center transition-all hover:-translate-y-0.5 ${
                                                                isShared 
                                                                    ? 'bg-indigo-50 border-indigo-200 shadow-sm' 
                                                                    : 'bg-white border-slate-200 hover:border-slate-300'
                                                            }`}
                                                        >
                                                            <span className={`text-lg font-black ${isShared ? 'text-indigo-900' : 'text-slate-700'}`}>{room}</span>
                                                            <span className={`text-[10px] font-bold uppercase tracking-widest mt-1 flex items-center gap-1 ${isShared ? 'text-indigo-600' : 'text-slate-400'}`}>
                                                                {isShared ? <><BedDouble size={12}/> {bedsPerSharedRoom} Beds</> : <><UserIcon size={12}/> Single</>}
                                                            </span>
                                                        </button>
                                                    );
                                                })}
                                            </div>
                                        </div>
                                    )
                                })}
                            </div>
                        ) : (
                            <div className="text-center py-10 text-slate-400 italic text-sm">Enter a valid floor and room range to see the matrix.</div>
                        )}
                    </div>

                    {/* RIGHT COLUMN: STAGING QUEUE */}
                    <div className="w-full lg:w-1/3 bg-white flex flex-col">
                        <div className="p-6 border-b border-slate-100 bg-slate-50/50">
                            <h3 className="text-sm font-black text-slate-800 uppercase tracking-widest mb-1">Staging Queue</h3>
                            <p className="text-xs text-slate-500">Review your built configurations here before executing the final database deployment.</p>
                        </div>
                        
                        <div className="flex-1 overflow-y-auto p-6 space-y-4 custom-scrollbar bg-slate-50/30">
                            {blueprintQueue.length === 0 ? (
                                <div className="text-center py-16 text-slate-400 italic text-sm border-2 border-dashed border-slate-200 rounded-2xl">
                                    Queue is empty.<br/>Configure on the left and Add to Queue.
                                </div>
                            ) : (
                                blueprintQueue.map((item, idx) => (
                                    <div key={item.id} className="bg-white p-5 rounded-2xl border border-blue-100 shadow-sm relative group hover:border-blue-300 transition-all">
                                        <div className="flex justify-between items-start mb-3">
                                            <span className="text-xs font-black bg-emerald-100 text-emerald-800 px-2.5 py-1 rounded-md">Batch {idx + 1}</span>
                                            <button onClick={() => removeFromQueue(item.id)} className="text-slate-300 hover:text-rose-500 opacity-0 group-hover:opacity-100 transition-opacity"><Trash2 size={16}/></button>
                                        </div>
                                        <p className="font-black text-slate-800 mb-1 leading-tight">
                                            {item.suffixes.map((s: string) => `${item.baseBlockName} ${s}`).join(', ')}
                                        </p>
                                        <p className="text-xs text-slate-500 font-medium mb-3">{item.summary}</p>
                                        
                                        <div className="bg-slate-50 rounded-lg p-3 border border-slate-100">
                                            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">Room Preview (Per Block)</p>
                                            <div className="flex flex-wrap gap-1.5">
                                                {item.templateRooms.slice(0, 8).map((r: any, i: number) => (
                                                    <span key={i} className={`text-[10px] px-1.5 py-0.5 rounded font-bold ${r.isShared ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-200 text-slate-600'}`}>
                                                        {item.combineNames ? item.suffixes[0] : ''}{r.baseNumber}{r.isShared && ' (S)'}
                                                    </span>
                                                ))}
                                                {item.templateRooms.length > 8 && <span className="text-[10px] text-slate-400 font-bold px-1 py-0.5">+{item.templateRooms.length - 8} more</span>}
                                            </div>
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>

                        {/* Sticky Action Footer */}
                        <div className="p-6 bg-white border-t border-slate-200 shadow-[0_-10px_20px_rgba(0,0,0,0.02)] space-y-4">
                            <button 
                                form="builder-form" 
                                type="submit" 
                                disabled={isDeploying}
                                className="w-full py-3.5 border-2 border-dashed border-blue-300 text-blue-600 rounded-xl text-sm font-black hover:bg-blue-50 transition-colors disabled:opacity-50"
                            >
                                + ADD BATCH TO QUEUE
                            </button>

                            <button 
                                onClick={deployBlueprint} 
                                disabled={blueprintQueue.length === 0 || isDeploying}
                                className={`w-full py-4 rounded-xl text-sm font-black flex items-center justify-center gap-2 transition-all shadow-lg ${
                                    blueprintQueue.length === 0 ? 'bg-slate-200 text-slate-400 shadow-none' : 
                                    isDeploying ? 'bg-indigo-600 text-white animate-pulse' : 'bg-emerald-500 text-white hover:bg-emerald-600 hover:shadow-emerald-500/30 hover:-translate-y-0.5'
                                }`}
                            >
                                {isDeploying ? (
                                    <><Loader2 size={18} className="animate-spin" /> {deployStatus}</>
                                ) : (
                                    <><CheckCircle2 size={18} /> DEPLOY FULL ACCOMMODATION</>
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}

// ============================================================================
// STANDARD ACCOMMODATION MODAL
// ============================================================================
function AccommodationModal({ onClose, onSuccess, initialData }: any) {
    const [formData, setFormData] = useState(initialData || { name: '', address: '', key_price: '', gender_target: 'MIXED' });
    const [logoFile, setLogoFile] = useState<File | null>(null);
    const [loading, setLoading] = useState(false);
    const isEdit = !!initialData;

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        const method = isEdit ? 'PATCH' : 'POST';
        const url = isEdit ? `/accommodations/${initialData.id}/` : '/accommodations/';
        
        try {
            const payload = new FormData();
            payload.append('name', formData.name);
            payload.append('address', formData.address);
            payload.append('key_price', formData.key_price);
            payload.append('gender_target', formData.gender_target);
            if (logoFile) {
                payload.append('accommodation_logo', logoFile);
            }

            const res = await apiFetch(url, { method, body: payload });
            onSuccess(res, isEdit);
        } catch (err) { alert("Save failed."); } finally { setLoading(false); }
    };

    return (
        <ModalWrapper title={isEdit ? "Edit Property" : "Add Property"} onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-4">
                {isEdit && initialData.accommodation_logo_url && (
                    <div className="flex items-center gap-4 mb-4">
                        <img src={initialData.accommodation_logo_url} alt="Current Logo" className="w-16 h-16 rounded-xl object-cover border" />
                        <span className="text-xs text-slate-500 font-bold">Current Active Logo</span>
                    </div>
                )}
                <div>
                    <label className="block text-xs font-bold text-slate-500 uppercase tracking-widest mb-1.5">Property Logo Image (Optional)</label>
                    <input type="file" accept="image/*" onChange={(e) => setLogoFile(e.target.files ? e.target.files[0] : null)} className="w-full text-sm text-slate-500 file:mr-4 file:py-2.5 file:px-4 file:rounded-xl file:border-0 file:text-xs file:font-black file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 cursor-pointer" />
                </div>
                <Input label="Property Name" value={formData.name} onChange={(e:any) => setFormData({...formData, name: e.target.value})} required />
                <Input label="Physical Address" value={formData.address} onChange={(e:any) => setFormData({...formData, address: e.target.value})} required />
                <Select label="Gender Designation" value={formData.gender_target} onChange={(e:any) => setFormData({...formData, gender_target: e.target.value})} required>
                    <option value="MIXED">Mixed / Co-ed</option>
                    <option value="MALE">Male Only</option>
                    <option value="FEMALE">Female Only</option>
                </Select>
                <Input type="number" label="Lost Key Price (R)" value={formData.key_price} onChange={(e:any) => setFormData({...formData, key_price: e.target.value})} required />
                <SubmitButton loading={loading} text="SAVE PROPERTY" />
            </form>
        </ModalWrapper>
    );
}