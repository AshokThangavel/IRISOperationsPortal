/// Global metric columns shared by the per-global, per-routine and per-process global tables.
Class SysPerf.PM.GlobalMetrics [ Abstract ]
{

/// Total global references
Property TotRefs As %Double;

/// % of all references
Property PctRefs As %Double;

Property GloSet As %Double;

Property GloKill As %Double;

/// Blocks allocated (database growth)
Property BlkAlloc As %Double;

/// Journal entries
Property JrnEntry As %Double;

/// Physical block reads (cache misses)
Property PhyBlkRd As %Double;

/// Physical block writes
Property PhyBlkWrt As %Double;

/// Logical block reads
Property LogBlkRd As %Double;

/// Derived: references per second
Property RefsPerSec As %Double;

/// Derived: physical reads per second
Property PhyRdPerSec As %Double;

/// Derived: journal entries per second
Property JrnPerSec As %Double;

/// Derived: updates (set+kill) per second
Property UpdPerSec As %Double;

/// Derived: 100 * PhyBlkRd / LogBlkRd (cache miss ratio)
Property MissPct As %Double;

}
