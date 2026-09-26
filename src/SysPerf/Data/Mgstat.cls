/// One ^mgstat sample (one line of the mgstat section). All counters are per second as reported by mgstat.
/// Column names that are unknown to this class (newer IRIS versions) are kept in <property>Extra</property>.
Class SysPerf.Data.Mgstat Extends SysPerf.Data.Child [ SqlTableName = Mgstat ]
{

Parameter DEFAULTGLOBAL = "^SysPerf.Mgstat";

Property SampleNo As %Integer;

Property SampleTS As %TimeStamp;

/// Global references / sec
Property Glorefs As %Double;

/// Remote (ECP) global references
Property RemGrefs As %Double;

/// Remote global reference ratio
Property GRratio As %Double;

/// Physical database reads / sec
Property PhyRds As %Double;

/// Glorefs per physical read
Property Rdratio As %Double;

/// Global updates (SET/KILL) / sec
Property Gloupds As %Double;

Property RemGupds As %Double;

/// Routine references / sec
Property Rourefs As %Double;

Property RemRrefs As %Double;

/// Routine loads and saves / sec (routine cache misses)
Property RouLaS As %Double;

Property RemRLaS As %Double;

/// Physical database writes / sec (write daemon)
Property PhyWrs As %Double;

/// Write daemon queue size
Property WDQsz As %Double;

/// Write daemon temporary queue
Property WDtmpq As %Double;

/// Write daemon phase
Property WDphase As %Double;

/// WIJ writes / sec
Property WIJwri As %Double;

/// Routine cache misses
Property RouCMs As %Double;

/// Journal writes / sec
Property Jrnwrts As %Double;

Property GblSz As %Double;

Property pGblNsz As %Double;

Property pGblAsz As %Double;

Property ObjSz As %Double;

Property pObjNsz As %Double;

Property pObjAsz As %Double;

Property BDBSz As %Double;

Property pBDBNsz As %Double;

Property pBDBAsz As %Double;

/// Active ECP connections
Property ActECP As %Double;

/// Blocks added to databases (expansion) / sec
Property Addblk As %Double;

Property PrgBufL As %Double;

Property PrgSrvR As %Double;

Property BytSnt As %Double;

Property BytRcd As %Double;

/// Write daemon passes (cumulative)
Property WDpass As %Double;

Property IJUcnt As %Double;

Property IJULock As %Double;

/// Process private global references
Property PPGrefs As %Double;

Property PPGupds As %Double;

/// Derived: global buffer cache hit % = 100*(1-PhyRds/Glorefs)
Property CacheHitPct As %Double;

/// Columns not mapped to a property: name -> value
Property Extra As array Of %String(MAXLEN = 100);

Index TSIdx On SampleTS;

Index RunTS On (Run, SampleTS);

Storage Default
{
<Data name="Extra">
<Attribute>Extra</Attribute>
<Structure>subnode</Structure>
<Subscript>"Extra"</Subscript>
</Data>
<Data name="MgstatDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Run</Value>
</Value>
<Value name="3">
<Value>SampleNo</Value>
</Value>
<Value name="4">
<Value>SampleTS</Value>
</Value>
<Value name="5">
<Value>Glorefs</Value>
</Value>
<Value name="6">
<Value>RemGrefs</Value>
</Value>
<Value name="7">
<Value>GRratio</Value>
</Value>
<Value name="8">
<Value>PhyRds</Value>
</Value>
<Value name="9">
<Value>Rdratio</Value>
</Value>
<Value name="10">
<Value>Gloupds</Value>
</Value>
<Value name="11">
<Value>RemGupds</Value>
</Value>
<Value name="12">
<Value>Rourefs</Value>
</Value>
<Value name="13">
<Value>RemRrefs</Value>
</Value>
<Value name="14">
<Value>RouLaS</Value>
</Value>
<Value name="15">
<Value>RemRLaS</Value>
</Value>
<Value name="16">
<Value>PhyWrs</Value>
</Value>
<Value name="17">
<Value>WDQsz</Value>
</Value>
<Value name="18">
<Value>WDtmpq</Value>
</Value>
<Value name="19">
<Value>WDphase</Value>
</Value>
<Value name="20">
<Value>WIJwri</Value>
</Value>
<Value name="21">
<Value>RouCMs</Value>
</Value>
<Value name="22">
<Value>Jrnwrts</Value>
</Value>
<Value name="23">
<Value>GblSz</Value>
</Value>
<Value name="24">
<Value>pGblNsz</Value>
</Value>
<Value name="25">
<Value>pGblAsz</Value>
</Value>
<Value name="26">
<Value>ObjSz</Value>
</Value>
<Value name="27">
<Value>pObjNsz</Value>
</Value>
<Value name="28">
<Value>pObjAsz</Value>
</Value>
<Value name="29">
<Value>BDBSz</Value>
</Value>
<Value name="30">
<Value>pBDBNsz</Value>
</Value>
<Value name="31">
<Value>pBDBAsz</Value>
</Value>
<Value name="32">
<Value>ActECP</Value>
</Value>
<Value name="33">
<Value>Addblk</Value>
</Value>
<Value name="34">
<Value>PrgBufL</Value>
</Value>
<Value name="35">
<Value>PrgSrvR</Value>
</Value>
<Value name="36">
<Value>BytSnt</Value>
</Value>
<Value name="37">
<Value>BytRcd</Value>
</Value>
<Value name="38">
<Value>WDpass</Value>
</Value>
<Value name="39">
<Value>IJUcnt</Value>
</Value>
<Value name="40">
<Value>IJULock</Value>
</Value>
<Value name="41">
<Value>PPGrefs</Value>
</Value>
<Value name="42">
<Value>PPGupds</Value>
</Value>
<Value name="43">
<Value>CacheHitPct</Value>
</Value>
</Data>
<DataLocation>^SysPerf.MgstatD</DataLocation>
<DefaultData>MgstatDefaultData</DefaultData>
<IdLocation>^SysPerf.MgstatD</IdLocation>
<IndexLocation>^SysPerf.MgstatI</IndexLocation>
<StreamLocation>^SysPerf.MgstatS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
