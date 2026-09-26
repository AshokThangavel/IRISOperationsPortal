/// Abstract superclass for every table that belongs to a <class>SysPerf.Data.Run</class>.
/// Each subclass gets its own extent (NoExtent) and inherits the Run reference + bitmap index.
Class SysPerf.Data.Child Extends %Persistent [ Abstract, NoExtent ]
{

Property Run As SysPerf.Data.Run [ Required ];

Index RunIdx On Run [ Type = bitmap ];

}
