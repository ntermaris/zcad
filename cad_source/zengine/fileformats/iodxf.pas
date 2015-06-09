﻿{
*****************************************************************************
*                                                                           *
*  This file is part of the ZCAD                                            *
*                                                                           *
*  See the file COPYING.modifiedLGPL.txt, included in this distribution,    *
*  for details about the copyright.                                         *
*                                                                           *
*  This program is distributed in the hope that it will be useful,          *
*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
*                                                                           *
*****************************************************************************
}
{
@author(Andrey Zubarev <zamtmn@yandex.ru>) 
}
{$MODE OBJFPC}
unit iodxf;
{$INCLUDE def.inc}
interface
uses gdbdrawcontext,usimplegenerics,ugdbdimstylearray,gdbentityfactory,{$IFNDEF DELPHI}dxfvectorialreader,svgvectorialreader,epsvectorialreader,fpvectorial,fileutil,{$ENDIF}UGDBNamedObjectsArray,ugdbltypearray,ugdbsimpledrawing,zcadsysvars,zcadinterface,{pdfvectorialreader,}GDBCircle,GDBArc,oglwindowdef,dxflow,zcadstrconsts,UGDBTextStyleArray,varman,geometry,GDBSubordinated,shared,gdbasetypes{,GDBRoot},log,GDBGenericSubEntry,SysInfo,gdbase, {GDBManager,} {OGLtypes,} sysutils{, strmy}, memman, {UGDBDescriptor,}gdbobjectsconstdef,
     UGDBObjBlockdefArray,UGDBOpenArrayOfTObjLinkRecord{,varmandef},UGDBOpenArrayOfByte,UGDBVisibleOpenArray,GDBEntity{,GDBBlockInsert,GDBCircle,GDBArc,GDBPoint,GDBText,GDBMtext,GDBLine,GDBPolyLine,GDBLWPolyLine},TypeDescriptors;
type
   entnamindex=record
                    entname:GDBString;
              end;
const
     acadentignoredcol=1;
     ignorenamtable:array[1..acadentignoredcol]of entnamindex=
     (
     (entname:'HATCH')
     );
     {acadentsupportcol=14;
     entnamtable:array[1..acadentsupportcol]of entnamindex=
     (
     (entname:'POINT'),
     (entname:'LINE'),
     (entname:'CIRCLE'),
     (entname:'POLYLINE'),
     (entname:'TEXT'),
     (entname:'ARC'),
     (entname:'INSERT'),
     (entname:'MTEXT'),
     (entname:'LWPOLYLINE'),
     (entname:'3DFACE'),
     (entname:'SOLID'),
     (entname:'ELLIPSE'),
     (entname:'SPLINE'),
     (entname:'DIMENSION')
     );}
     NULZCPHeader:ZCPHeader=(
     Signature:'';
     Copyright:'';
     Coment:'';
     HiVersion:0;
     LoVersion:0;
     OffsetTable:(
                  GDB:0;
                  GDBRT:0;
                 );
                );
{$IFDEF DEBUGBUILD}
var i2:GDBInteger;
{$ENDIF}
var FOC:GDBInteger;
procedure addfromdxf(name: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing);
function savedxf2000(name: GDBString; {PDrawing:PTSimpleDrawing}var drawing:TSimpleDrawing):boolean;
procedure saveZCP(name: GDBString; {gdb: PGDBDescriptor}var drawing:TSimpleDrawing);
procedure LoadZCP(name: GDBString; {gdb: PGDBDescriptor}var drawing:TSimpleDrawing);
{$IFNDEF DELPHI}
procedure Import(name: GDBString;var drawing:TSimpleDrawing);
{$ENDIF}
implementation
uses enitiesextendervariables,GDBLine,GDBBlockDef,UGDBLayerArray,varmandef,fileformatsmanager;

function IsIgnoredEntity(name:GDBString):GDBInteger;
var i:GDBInteger;
begin
     result:=-1;
     for i:=1 to acadentignoredcol do
          if uppercase(ignorenamtable[i].entname)=uppercase(name) then
          begin
               result:=i;
               exit;
          end;
end;

{function entname2GDBID(name:GDBString):GDBInteger;
var i:GDBInteger;
begin
     result:=-1;
     for i:=1 to acadentsupportcol do
          if uppercase(entnamtable[i].entname)=uppercase(name) then
          begin
               result:=i;
               exit;
          end;
end;}
procedure gotodxf(var f: GDBOpenArrayOfByte; fcode: GDBInteger; fname: GDBString);
var
  byt: GDBByte;
  s: GDBString;
  error: GDBInteger;
begin
  if fname<>'' then
  begin
  while f.notEOF do
  begin
    s := f.readGDBString;
    val(s, byt, error);
    if error <> 0 then
      s := s{чето тут не так};
    s := f.readGDBString;
    if (byt = fcode) and (s = fname) then
      exit;
  end;
  end
  else
  begin
  while f.notEOF do
  begin
    s := f.readGDBString;
    val(s, byt, error);
    if error <> 0 then
      s := s{чето тут не так};
    if (byt = fcode) then
          exit;
    s := f.readGDBString;
  end;
  end;
end;
procedure readvariables(var f: GDBOpenArrayOfByte;var ctstyle:GDBstring; var clayer:GDBString;var cltype:GDBString;var cdimstyle:GDBString;LoadMode:TLoadOpt;DWGVarsDict:TGDBString2GDBStringDictionary);
var
  byt: GDBByte;
  s: GDBString;
  error: GDBInteger;
begin
     if LoadMode=TLOLoad then
     begin
     DWGVarsDict.mygetvalue('$CLAYER',clayer);
     DWGVarsDict.mygetvalue('$TEXTSTYLE',ctstyle);
     DWGVarsDict.mygetvalue('$DIMSTYLE',cdimstyle);
     DWGVarsDict.mygetvalue('$CELTYPE',cltype);
     if sysvar.DWG.DWG_CLinew<>nil then
       if DWGVarsDict.mygetvalue('$CELWEIGHT',s) then
         sysvar.DWG.DWG_CLinew^:=strtoint(s);
     if sysvar.DWG.DWG_DrawMode<>nil then
       if DWGVarsDict.mygetvalue('$LWDISPLAY',s) then
         case strtoint(s) of
             1:sysvar.DWG.DWG_DrawMode^ := true;
             0:sysvar.DWG.DWG_DrawMode^ := false;
         end;
     if sysvar.DWG.DWG_LTScale<>nil then
       if DWGVarsDict.mygetvalue('$LTSCALE',s) then
         sysvar.DWG.DWG_LTScale^ := strtofloat(s);
     if sysvar.DWG.DWG_CLTScale<>nil then
       if DWGVarsDict.mygetvalue('$CELTSCALE',s) then
         sysvar.DWG.DWG_CLTScale^ := strtofloat(s);
     if sysvar.DWG.DWG_CColor<>nil then
       if DWGVarsDict.mygetvalue('$CECOLOR',s) then
         sysvar.DWG.DWG_CColor^ := strtoint(s);
     if sysvar.DWG.DWG_LUnits<>nil then
       if DWGVarsDict.mygetvalue('$LUNITS',s) then
         sysvar.DWG.DWG_LUnits^ := TLUnits(strtoint(s)-1);
     if sysvar.DWG.DWG_LUPrec<>nil then
       if DWGVarsDict.mygetvalue('$LUPREC',s) then
         sysvar.DWG.DWG_LUPrec^ := TUPrec(strtoint(s));
     if sysvar.DWG.DWG_AUnits<>nil then
       if DWGVarsDict.mygetvalue('$AUNITS',s) then
         sysvar.DWG.DWG_AUnits^ := TAUnits(strtoint(s));
     if sysvar.DWG.DWG_AUPrec<>nil then
       if DWGVarsDict.mygetvalue('$AUPREC',s) then
         sysvar.DWG.DWG_AUPrec^ := TUPrec(strtoint(s));
     if sysvar.DWG.DWG_AngDir<>nil then
       if DWGVarsDict.mygetvalue('$ANGDIR',s) then
         sysvar.DWG.DWG_AngDir^ := TAngDir(strtoint(s));
     if sysvar.DWG.DWG_AngBase<>nil then
       if DWGVarsDict.mygetvalue('$ANGBASE',s) then
         sysvar.DWG.DWG_AngBase^ := strtofloat(s);
     if sysvar.DWG.DWG_UnitMode<>nil then
       if DWGVarsDict.mygetvalue('$UNITMODE',s) then
         sysvar.DWG.DWG_UnitMode^ := TUnitMode(strtoint(s));
     if sysvar.DWG.DWG_InsUnits<>nil then
       if DWGVarsDict.mygetvalue('$INSUNITS',s) then
         sysvar.DWG.DWG_InsUnits^ := TInsUnits(strtoint(s));
     if sysvar.DWG.DWG_TextSize<>nil then
       if DWGVarsDict.mygetvalue('$TEXTSIZE',s) then
         sysvar.DWG.DWG_TextSize^ := strtofloat(s);
     end;
end;
procedure ReadDXFHeader(var f: GDBOpenArrayOfByte; DWGVarsDict:TGDBString2GDBStringDictionary);
type
   TDXFHeaderMode=(TDXFHMWaitSection,TDXFHMSection,TDXFHMHeader);
const
   maxlines=9;
var
  group: GDBByte;
  s,varname: GDBString;
  error,varcount: GDBInteger;
  ParseMode:TDXFHeaderMode;
  grouppsarray:array[0..maxlines]of integer;
  valuesarray:array[0..maxlines]of string;
  currentindex,maxindex:integer;

procedure storevariable;
begin
     case currentindex of
     0:DWGVarsDict.insert(varname,valuesarray[0]);
     1:DWGVarsDict.insert(varname,valuesarray[0]+'|'+valuesarray[1]);
     else DWGVarsDict.insert(varname,valuesarray[0]+'|'+valuesarray[1]+'|'+valuesarray[2]);
     end;
     currentindex:=-1;
end;
procedure processvalue(const group:integer;const value:gdbstring);
begin
     inc(currentindex);
     if currentindex>maxindex then
                                  maxindex:=currentindex;
     grouppsarray[currentindex]:=group;
     valuesarray[currentindex]:=value;
end;
procedure freearrays;
var
   i:integer;
begin
     for i:=0 to maxindex do
                            valuesarray[i]:='';
end;
begin
  ParseMode:=TDXFHMWaitSection;
  varcount:=0;
  currentindex:=-1;
  maxindex:=currentindex;
  try
  while f.notEOF do
  begin
    s := f.readGDBString;
    val(s, group, error);
    if error <> 0 then
                      shared.ShowError('ReadDXFHeader wrong group code');
    s := f.readGDBString;
    case ParseMode of
    TDXFHMWaitSection:begin
                           if uppercase(s)=dxfName_SECTION then
                                                             begin
                                                                  ParseMode:=TDXFHMSection;
                                                             end
                                                            else
                                                             shared.ShowError('ReadDXFHeader error');

                      end;
        TDXFHMSection:begin
                           if uppercase(s)=dxfName_HEADER then
                                                            begin
                                                              ParseMode:=TDXFHMHeader;
                                                            end
                                                          else
                                                            shared.ShowError('ReadDXFHeader error');
                      end;
         TDXFHMHeader:begin
                           if group=0 then
                           if uppercase(s)=dxfName_ENDSEC then
                                                              exit;
                           if group=9 then
                                          begin
                                               if varcount>0 then
                                                                 storevariable;
                                               varname:=s;
                                               inc(varcount);
                                          end
                                      else
                                          begin
                                               processvalue(group,s);
                                          end
                              end;
    end;{case}
    end;
    finally
    freearrays;
  end;
end;

function GoToDXForENDTAB(var f: GDBOpenArrayOfByte; fcode: GDBInteger; fname: GDBString):boolean;
var
  byt: GDBByte;
  s: GDBString;
  error: GDBInteger;
begin
  result:=false;
  while f.notEOF do
  begin
    s := f.readGDBString;
    val(s, byt, error);
    if error <> 0 then
      s := s{чето тут не так};
    s := f.readGDBString;
    if (byt = fcode) and (s = fname) then
                                         begin
                                              result:=true;
                                              exit;
                                         end;
    if (byt = 0) and (uppercase(s) = dxfName_ENDTAB) then
                                         begin
                                              exit;
                                         end;
  end;
end;

procedure correctvariableset(pobj: PGDBObjEntity);
var vd:vardesk;
    pentvarext:PTVariablesExtender;
begin
     //if (pobj.vp.ID=GDBBlockInsertID)or
     //   (pobj.vp.ID=GDBCableID) then
     pentvarext:=pobj^.GetExtension(typeof(TVariablesExtender));
     if pentvarext<>nil then
        begin
             if pentvarext^.entityunit.FindVariable('GC_HeadDevice')<>nil then
             if pentvarext^.entityunit.FindVariable('GC_Metric')=nil then
             begin
                  pentvarext^.entityunit.setvardesc(vd,'GC_Metric','','GDBString');
                  pentvarext^.entityunit.InterfaceVariables.createvariable(vd.name,vd);
             end;

             if pentvarext^.entityunit.FindVariable('GC_HDGroup')<>nil then
             if pentvarext^.entityunit.FindVariable('GC_HDGroupTemplate')=nil then
             begin
                  pentvarext^.entityunit.setvardesc(vd,'GC_HDGroupTemplate','Шаблон группы','GDBString');
                  pentvarext^.entityunit.InterfaceVariables.createvariable(vd.name,vd);
             end;
             if pentvarext^.entityunit.FindVariable('GC_HeadDevice')<>nil then
             if pentvarext^.entityunit.FindVariable('GC_HeadDeviceTemplate')=nil then
             begin
                  pentvarext^.entityunit.setvardesc(vd,'GC_HeadDeviceTemplate','Шаблон головного устройства','GDBString');
                  pentvarext^.entityunit.InterfaceVariables.createvariable(vd.name,vd);
             end;

             if pentvarext^.entityunit.FindVariable('GC_HDShortName')<>nil then
             if pentvarext^.entityunit.FindVariable('GC_HDShortNameTemplate')=nil then
             begin
                  pentvarext^.entityunit.setvardesc(vd,'GC_HDShortNameTemplate','Шаблон короткого имени головного устройства','GDBString');
                  pentvarext^.entityunit.InterfaceVariables.createvariable(vd.name,vd);
             end;
             if pentvarext^.entityunit.FindVariable('GC_Metric')<>nil then
             if pentvarext^.entityunit.FindVariable('GC_InGroup_Metric')=nil then
             begin
                  pentvarext^.entityunit.setvardesc(vd,'GC_InGroup_Metric','Метрика нумерации в группе','GDBString');
                  pentvarext^.entityunit.InterfaceVariables.createvariable(vd.name,vd);
             end;


        end;
end;

procedure addentitiesfromdxf(var f: GDBOpenArrayOfByte;exitGDBString: GDBString;owner:PGDBObjSubordinated;var drawing:TSimpleDrawing;h2p:TMapHandleToPointer);
var
//  byt,LayerColor: GDBInteger;
  s{, sname, sx1, sy1, sz1,scode,LayerName}: GDBString;
//  ErrorCode,GroupCode: GDBInteger;
group:integer;
objid: GDBInteger;
  pobj,postobj: PGDBObjEntity;
//  tp: PGDBObjBlockdef;
  newowner:PGDBObjSubordinated;
  m4:DMatrix4D;
  trash:boolean;
  additionalunit:TUnit;
  EntInfoData:TEntInfoData;
  DC:TDrawContext;
  pentvarext,ppostentvarext:PTVariablesExtender;
  bylayerlt:GDBPointer;
begin
  additionalunit.init('temparraryunit');
  additionalunit.InterfaceUses.addnodouble(@SysUnit);
  group:=-1;
  bylayerlt:=drawing.LTypeStyleTable.getAddres('ByLayer');
  while (f.notEOF) and (s <> exitGDBString) do
  begin
    if assigned(ProcessLongProcessProc) then
                                            ProcessLongProcessProc(f.ReadPos);
    s := f.readGDBString;
    if (group=0)and(DXFName2EntInfoData.MyGetValue(s,EntInfoData)) then
    //objid:=entname2GDBID(s);
    //if (objid>0)and(group=0) then
    begin
    if owner <> nil then
      begin
        programlog.LogOutFormatStr('AddEntitiesFromDXF.Found primitive %s',[s],lp_OldPos,LM_Trace);
        {$IFDEF DEBUGBUILD}inc(i2);if i2=4349 then
                                                  i2:=i2;{$ENDIF}
        pobj := EntInfoData.AllocAndInitEntity(nil);
        //pobj := {po^.CreateInitObj(objid,owner)}CreateInitObjFree(objid,nil);
        PGDBObjEntity(pobj)^.LoadFromDXF(f,@additionalunit,drawing);
        if (PGDBObjEntity(pobj)^.vp.Layer=@DefaultErrorLayer)or(PGDBObjEntity(pobj)^.vp.Layer=nil) then
                                                                 PGDBObjEntity(pobj)^.vp.Layer:=drawing.LayerTable.GetSystemLayer;
        if (PGDBObjEntity(pobj)^.vp.LineType=nil) then
                                                      PGDBObjEntity(pobj)^.vp.LineType:={drawing.LTypeStyleTable.getAddres('ByLayer')}bylayerlt;
        correctvariableset(pobj);
        pointer(postobj):=PGDBObjEntity(pobj)^.FromDXFPostProcessBeforeAdd(@additionalunit,drawing);
        trash:=false;
        if postobj=nil  then
                            begin
                                newowner:=owner;
                                if PGDBObjEntity(pobj)^.PExtAttrib<>nil then
                                begin
                                     if PGDBObjEntity(pobj)^.PExtAttrib^.Handle>200 then
                                                                                      h2p.Insert(PGDBObjEntity(pobj)^.PExtAttrib^.Handle,pobj);
                                                                                      //pushhandle(phandlearray,PGDBObjEntity(pobj)^.PExtAttrib^.Handle,GDBPlatformint(pobj));
                                     if PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle>200 then
                                                                                      newowner:=h2p.MyGetValue(PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle);
                                                                                      //newowner:=pointer(getnevhandleWithNil(phandlearray,PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle));
                                     if PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle=h_trash then
                                                                                      trash:=true;


                                end;
                                if newowner=nil then
                                                    begin
                                                         historyoutstr('Warning! OwnerHandle $'+inttohex(PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle,8)+' not found');
                                                         newowner:=owner;
                                                    end;

                                if not trash then
                                begin
                                if (newowner<>owner) then
                                begin
                                     m4:=PGDBObjEntity(newowner)^.getmatrix^;
                                     MatrixInvert(m4);
                                     //pobj^.Format;
                                     pobj^.CalcObjMatrix;
                                     pobj^.transform(m4);
                                end
                                else
                                    pobj^.CalcObjMatrix;
                                end;
                                if not trash then
                                begin
                                 newowner^.AddMi(@pobj);
                                    if foc=0 then
                                                 begin
                                                      PGDBObjEntity(pobj)^.BuildGeometry(drawing);
                                                      //PGDBObjEntity(pobj)^.Format;
                                                      PGDBObjEntity(pobj)^.FormatAfterDXFLoad(drawing);
                                                      PGDBObjEntity(pobj)^.FromDXFPostProcessAfterAdd;
                                                 end;
                                end
                                   else
                                       begin
                                 pobj^.done;
                                 GDBFreeMem(pointer(pobj));

                                       end;

                            end
                        else
                            begin
                                newowner:=owner;
                                if PGDBObjEntity(pobj)^.PExtAttrib<>nil then
                                begin
                                     if PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle>200 then
                                                                                      newowner:=h2p.MyGetValue(PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle);
                                                                                      //newowner:=pointer(getnevhandleWithNil(phandlearray,PGDBObjEntity(pobj)^.PExtAttrib^.OwnerHandle));
                                end;
                                if newowner<>nil then
                                begin
                                if PGDBObjEntity(pobj)^.PExtAttrib<>nil then
                                begin
                                     if PGDBObjEntity(pobj)^.PExtAttrib^.Handle>200 then
                                                                                      h2p.Insert(PGDBObjEntity(pobj)^.PExtAttrib^.Handle,postobj);
                                                                                      //pushhandle(phandlearray,PGDBObjEntity(pobj)^.PExtAttrib^.Handle,GDBPlatformint(postobj));
                                end;
                                if newowner=pointer($ffffffff) then
                                                           newowner:=newowner;
                                DC:=drawing.CreateDrawingRC;
                                if newowner<>owner then
                                begin
                                     m4:=PGDBObjEntity(newowner)^.getmatrix^;
                                     MatrixInvert(m4);
                                     postobj^.FormatEntity(drawing,dc);
                                     postobj^.transform(m4);
                                end;

                                 newowner^.AddMi(@postobj);
                                 pentvarext:=pobj^.GetExtension(typeof(TVariablesExtender));
                                 ppostentvarext:=postobj^.GetExtension(typeof(TVariablesExtender));
                                 //if pobj^.ou.Instance<>nil then
                                 if (pentvarext<>nil)and(ppostentvarext<>nil) then
                                 pentvarext^.entityunit.CopyTo(@ppostentvarext^.entityunit);
                                 if foc=0 then
                                              begin
                                                   PGDBObjEntity(postobj)^.BuildGeometry(drawing);
                                                   //PGDBObjEntity(postobj)^.Format;
                                                   PGDBObjEntity(postobj)^.FormatAfterDXFLoad(drawing);
                                                   PGDBObjEntity(postobj)^.FromDXFPostProcessAfterAdd;
                                              end;
                                end
                                   else
                                       begin
                                       newowner:=newowner;
                                       {//добавляем потеряный примитив
                                       owner^.AddMi(@postobj);
                                           if foc=0 then
                                                        begin
                                                        PGDBObjEntity(postobj)^.BuildGeometry(drawing);
                                                        PGDBObjEntity(postobj)^.FormatAfterDXFLoad(drawing);
                                                        PGDBObjEntity(postobj)^.FromDXFPostProcessAfterAdd;
                                                        end;}
                                       //вытираем потеряный примитив
                                       postobj^.done;
                                       GDBFreeMem(pointer(postobj));
                                       end;
                                   pobj^.done;
                                   GDBFreeMem(pointer(pobj));
                            end;
      end;
      additionalunit.free;
    end
    else
    begin
         if group=0 then
         begin
         objid:=IsIgnoredEntity(s);
         if objid>0 then
         gotodxf(f, 0, '');
         end
         else
             if trystrtoint(s,group)then
                                    else
                                        group:=-1;
    end;
  end;
  additionalunit.done;
end;
procedure addfromdxf12(var f:GDBOpenArrayOfByte;exitGDBString: GDBString;owner:PGDBObjSubordinated;LoadMode:TLoadOpt;var drawing:TSimpleDrawing);
var
  {byt,}LayerColor: GDBInteger;
  s, sname{, sx1, sy1, sz1},scode,LayerName: GDBString;
  ErrorCode,GroupCode: GDBInteger;

//objid: GDBInteger;
//  pobj,postobj: PGDBObjEntity;
  tp: PGDBObjBlockdef;
  //phandlearray: pdxfhandlerecopenarray;
  h2p:TMapHandleToPointer;
begin
  programlog.LogOutStr('AddFromDXF12',lp_IncPos,LM_Debug);
  //phandlearray := dxfhandlearraycreate(10000);
  h2p:=TMapHandleToPointer.Create;
  while (f.notEOF) and (s <> exitGDBString) do
  begin
  if assigned(ProcessLongProcessProc)then
  ProcessLongProcessProc(f.ReadPos);

    s := f.readGDBString;
    if s = dxfName_Layer then
    begin
      programlog.LogOutStr('Found layer table',lp_IncPos,LM_Debug);
      repeat
            scode := f.readGDBString;
            sname := f.readGDBString;
            val(scode,GroupCode,ErrorCode);
      until GroupCode=0;
      repeat
        if sname=dxfName_ENDTAB then system.break;
        if sname<>dxfName_Layer then FatalError('''LAYER'' expected but '''+sname+''' found');
        repeat
              scode := f.readGDBString;
              sname := f.readGDBString;
              val(scode,GroupCode,ErrorCode);
              case GroupCode of
                               2:LayerName:=sname;
                               62:val(sname,LayerColor,ErrorCode);
              end;{case}
        until GroupCode=0;
        programlog.LogOutFormatStr('Found layer ',[LayerName],lp_OldPos,LM_Debug);
        drawing.LayerTable.addlayer(LayerName,LayerColor,-3,true,false,true,'',TLOLoad);
      until sname=dxfName_ENDTAB;
      programlog.LogOutStr('end; {layer table}',lp_DecPos,LM_Debug);
    end
    else if s = 'BLOCKS' then
    begin
      programlog.LogOutStr('Found block table',lp_IncPos,LM_Debug);
      sname := '';
      repeat
        if sname = '  2' then
          if (s = '$MODEL_SPACE') or (s = '$PAPER_SPACE') then
          begin
            while (s <> 'ENDBLK') do
              s := f.readGDBString;
          end
          else
          begin
            tp := drawing.BlockDefArray.create(s);
            programlog.LogOutFormatStr('Found block "%s"',[s],lp_IncPos,LM_Debug);
            {addfromdxf12}addentitiesfromdxf(f, 'ENDBLK',tp,drawing,h2p);
            programlog.LogOutFormatStr('end; {block "%s"}',[s],lp_DecPos,LM_Debug);
          end;
        sname := f.readGDBString;
        s := f.readGDBString;
      until (s = dxfName_ENDSEC);
      programlog.LogOutStr('end; {block table}',lp_DecPos,LM_Debug);
    end
    else if s = 'ENTITIES' then
    begin
         programlog.LogOutStr('Found entities section',lp_IncPos,LM_Debug);
         addentitiesfromdxf(f, 'EOF',owner,drawing,h2p);
         programlog.LogOutStr('end {entities section}',lp_DecPos,LM_Debug);
    end;
  end;
  //GDBFreeMem(GDBPointer(phandlearray));
  h2p.Destroy;
  programlog.LogOutStr('end; {AddFromDXF12}',lp_DecPos,LM_Debug);
end;
procedure ReadLTStyles(var s:String;cltype:string;var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing;var h2p:TMapHandleToPointer);
var
   pltypeprop:PGDBLtypeProp;
   byt: GDBInteger;
   dashinfo:TDashInfo;
   shapenumber,stylehandle:TDWGHandle;
   PSP:PShapeProp;
   PTP:PTextProp;
   BShapeProp:BasicSHXDashProp;
   txtstr:string;
   TempDouble:GDBDouble;
   flags: GDBInteger;
   DWGHandle:TDWGHandle;
begin
  dashinfo:=TDIDash;
  if GoToDXForENDTAB(f, 0, dxfName_LType) then
  while s = dxfName_LType do
  begin
       pltypeprop:=nil;
       byt := 2;
       while byt <> 0 do
       begin
       s := f.readGDBString;
       byt := strtoint(s);
       s := f.readGDBString;
       case byt of
       2:
         begin
           case drawing.LTypeStyleTable.AddItem(s,pointer(pltypeprop)) of
                        IsFounded:
                                  begin
                                       h2p.Insert(DWGHandle,pltypeprop);
                                       if LoadMode=TLOLoad then
                                       begin
                                       end
                                       else
                                           pltypeprop:=nil;
                                  end;
                        IsCreated:
                                  begin
                                       pltypeprop^.init(s);
                                       dashinfo:=TDIDash;
                                       h2p.Insert(DWGHandle,pltypeprop);
                                  end;
                        IsError:
                                  begin
                                  end;
                end;
              if uppercase(s)=uppercase(cltype)then
                                                   if sysvar.DWG.DWG_CLType<>nil then
                                                                                     sysvar.DWG.DWG_CLType^:=pltypeprop;

         end;
       3:
         begin
              if pltypeprop<>nil then
                                pltypeprop^.desk:=s;
         end;
       5:begin
              DWGHandle:=strtoint64('$'+s)
         end;
       40:
         begin
              if pltypeprop<>nil then
              pltypeprop^.len:=strtofloat(s);
         end;
       49:
          begin
               if pltypeprop<>nil then
               begin
               case dashinfo of
               TDIShape:begin
                             if stylehandle<>0 then
                             begin
                                 pointer(psp):=pltypeprop^.shapearray.CreateObject;
                                 psp^.initnul;
                                 psp^.param:=BShapeProp.param;
                                 psp^.Psymbol:=pointer(shapenumber);
                                 psp^.param.PStyle:=pointer(stylehandle);
                                 psp^.param.PstyleIsHandle:=true;
                                 pltypeprop^.dasharray.Add(@dashinfo);
                             end;
                        end;
               TDIText:begin
                             pointer(ptp):=pltypeprop^.Textarray.CreateObject;
                             ptp^.initnul;
                             ptp^.param:=BShapeProp.param;
                             ptp^.Text:=txtstr;
                             //ptp^.Style:=;
                             ptp^.param.PStyle:=pointer(stylehandle);
                             psp^.param.PstyleIsHandle:=true;
                             pltypeprop^.dasharray.Add(@dashinfo);
                        end;
               end;
                    dashinfo:=TDIDash;
                    TempDouble:=strtofloat(s);
                    pltypeprop^.dasharray.Add(@dashinfo);
                    pltypeprop^.strokesarray.Add(@TempDouble);
               end;
          end;
       74:if pltypeprop<>nil then
          begin
               flags:=strtoint(s);
               if (flags and 1)>0 then
                                      BShapeProp.param.AD:={BShapeProp.param.AD.}TACAbs
                                  else
                                      BShapeProp.param.AD:={BShapeProp.param.AD.}TACRel;
               if (flags and 2)>0 then
                                      dashinfo:=TDIText;
               if (flags and 4)>0 then
                                      dashinfo:=TDIShape;

          end;
       75:begin
               shapenumber:=strtoint(s);//
          end;
      340:begin
               if pltypeprop<>nil then
                                      stylehandle:=strtoint64('$'+s);
          end;
      46:begin
              BShapeProp.param.Height:=strtofloat(s);
         end;
      50:begin
              BShapeProp.param.Angle:=strtofloat(s);
         end;
      44:begin
              BShapeProp.param.X:=strtofloat(s);
         end;
      45:begin
              BShapeProp.param.Y:=strtofloat(s);
         end;
      9:begin if pltypeprop<>nil then
              txtstr:=s;
         end;
       end;
       end;
  end;
end;
procedure ReadLayers(var s:string;clayer:string;var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing);
var
byt: GDBInteger;
lname,desk: String;
nulisread:boolean;
player:PGDBLayerProp;
begin
  nulisread:=false;
  gotodxf(f, 0, dxfName_Layer);
  player:=nil;
  while s = dxfName_Layer do
  begin
    byt := 2;
    while byt <> 0 do
    begin
      if not nulisread then
      begin
      s := f.readGDBString;
      byt := strtoint(s);
      s := f.readGDBString;
      end
      else
          nulisread:=false;
      case byt of
        2:
          begin
            programlog.LogOutFormatStr('Found layer  %s',[s],lp_OldPos,LM_Debug);
            lname:=s;
            player:=drawing.LayerTable.MergeItem(s,LoadMode);
            if player<>nil then
                               player^.init(s);
          end;
        6:
          begin
               if player<>nil then
                                  player^.LT:=drawing.LTypeStyleTable.getAddres(s);
          end;
        1001:
          begin
               if s='AcAecLayerStandard' then
                 begin
                      s := f.readGDBString;
                      byt:=strtoint(s);
                      if byt<>0 then
                      begin
                          s := f.readGDBString;
                          begin
                                s := f.readGDBString;
                                byt:=strtoint(s);
                                if byt<>0 then
                                              begin
                                                   desk := f.readGDBString;
                                                   if player<>nil then
                                                                      player^.desk:=desk;
                                              end
                                          else
                                              begin
                                              nulisread:=true;
                                              s := f.readGDBString;
                                              end;

                          end;
                      end
                         else
                         begin
                          nulisread:=true;
                          s := f.readGDBString;
                         end;
                 end;
           end;
         else begin
                   if player<>nil then
                                  player^.SetValueFromDxf(byt,s);
              end;

      end;
    end;

    if uppercase(lname)=uppercase(clayer)then
                                             if sysvar.DWG.DWG_CLayer<>nil then
                                                                               sysvar.DWG.DWG_CLayer^:=player;
  end;
end;
procedure ReadTextstyles(var s:string;ctstyle:string;var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing;var h2p:TMapHandleToPointer);
var
   tstyle:GDBTextStyle;
   ptstyle:PGDBTextStyle;
   DWGHandle:TDWGHandle;
   byt: GDBInteger;
   flags: GDBInteger;
   lname: String;
   ti:PGDBTextStyle;
   pltypeprop:PGDBLtypeProp;
   ir,ir2:itrec;
   PSP:PShapeProp;
   PTP:PTextProp;
   TDInfo:TTrianglesDataInfo;
begin
  if GoToDXForENDTAB(f, 0, dxfName_Style) then
  while s = dxfName_Style do
  begin
    tstyle.name:='';
    tstyle.pfont:=nil;
    tstyle.prop.oblique:=0;
    tstyle.prop.size:=1;
    DWGHandle:=0;

    byt := 2;

    while byt <> 0 do
    begin
      s := f.readGDBString;
      byt := strtoint(s);
      s := f.readGDBString;
      case byt of
        2:
          begin
            tstyle.name := s;
          end;
        5:begin
               DWGHandle:=strtoint64('$'+s)
          end;

        40:
          begin
            tstyle.prop.size:=strtofloat(s);
          end;
        41:
          begin
            tstyle.prop.wfactor:=strtofloat(s);
          end;
        50:
          begin
            tstyle.prop.oblique:=strtofloat(s);
          end;
        70:begin
                flags:=strtoint(s);
           end;
        3:
          begin
               lname:=s;
               //FontManager.addFonf(FindInPaths(sysvar.PATH.Fonts_Path^,s));
               //tstyle.pfont:=FontManager.getAddres(s);
               //if tstyle.pfont:=;
           end;
      end;
    end;
    ti:=nil;
    if (flags and 1)=0 then
    begin
    ti:=drawing.TextStyleTable.FindStyle(tstyle.Name,false);
    if ti<>nil then
    begin
      if LoadMode=TLOLoad then
                              ti:=drawing.TextStyleTable.setstyle(tstyle.Name,lname,tstyle.prop,false);
    end
       else
           ti:=drawing.TextStyleTable.addstyle(tstyle.Name,lname,tstyle.prop,false);
    end
    else
        begin
          if drawing.TextStyleTable.FindStyle(lname,true)<>nil then
          begin
            if LoadMode=TLOLoad then
                                    ti:=drawing.TextStyleTable.setstyle(lname,lname,tstyle.prop,true);
          end
             else
                 ti:=drawing.TextStyleTable.addstyle(lname,lname,tstyle.prop,true);
        end;
    if ti<>nil then
    begin
         h2p.Insert(DWGHandle,ti);
         ptstyle:={drawing.TextStyleTable.getelement}(ti);
         pltypeprop:=drawing.LTypeStyleTable.beginiterate(ir);
         if pltypeprop<>nil then
         repeat
               PSP:=pltypeprop^.shapearray.beginiterate(ir2);
               if PSP<>nil then
               repeat
                     if psp^.param.PstyleIsHandle then
                     if psp^.param.PStyle=pointer(DWGHandle) then
                     begin
                        psp^.param.PStyle:=ptstyle;
                        psp^.FontName:=ptstyle^.dxfname;
                        psp^.Psymbol:=ptstyle^.pfont^.GetOrReplaceSymbolInfo(integer(psp^.Psymbol),tdinfo);
                        psp^.SymbolName:=psp^.Psymbol^.Name;
                     end;

                     PSP:=pltypeprop^.shapearray.iterate(ir2);
               until PSP=nil;

               PTP:=pltypeprop^.Textarray.beginiterate(ir2);
               if PTP<>nil then
               repeat
                     if pTp^.param.PStyle=pointer(DWGHandle) then
                     begin
                        pTp^.param.PStyle:=ptstyle;
                        {pTp^.FontName:=ptstyle^.dxfname;
                        pTp^.Psymbol:=ptstyle^.pfont^.GetOrReplaceSymbolInfo(integer(pTp^.Psymbol));
                        pTp^.SymbolName:=pTp^.Psymbol^.Name;}
                     end;

                     PTP:=pltypeprop^.Textarray.iterate(ir2);
               until PTP=nil;

               pltypeprop:=drawing.LTypeStyleTable.iterate(ir);
         until pltypeprop=nil;
    end;
    programlog.LogOutFormatStr('Found style  %s',[tstyle.Name],lp_OldPos,LM_Debug);
   if uppercase(tstyle.Name)=uppercase(ctstyle)then
                if sysvar.DWG.DWG_CTStyle<>nil then
                                                  sysvar.DWG.DWG_CTStyle^:=drawing.TextStyleTable.FindStyle(tstyle.Name,false);
    tstyle.Name:='';
  end;
  drawing.LTypeStyleTable.format;
end;
procedure ReadVport(var s:string;var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing);
var
   byt: GDBInteger;
   active:boolean;
   flags: GDBInteger;
begin
     programlog.logoutstr('ReadVport',lp_IncPos,LM_Debug);
     if GoToDXForENDTAB(f, 0, 'VPORT') then
     begin
       byt := -100;
       active:=false;

       while byt <> 0 do
       begin
         s := f.readGDBString;
         byt := strtoint(s);
         programlog.LogOutFormatStr('Group :"%s"',[s],lp_OldPos,LM_Debug);
         s := f.readGDBString;
         programlog.LogOutFormatStr('Value :"%s"',[s],lp_OldPos,LM_Debug);
         if (byt=0)and(s='VPORT')then
         begin
               byt := -100;
               active:=false;
         end;
         case byt of
           2:
             begin
                  if uppercase(s)='*ACTIVE' then
                                                active:=true
                                            else
                                                active:=false;
             end;
           12:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if @drawing<>nil then
                  if drawing.pcamera<>nil then
                  begin
                       drawing.pcamera^.prop.point.x:=-strtofloat(s);
                  end;
              end;
           22:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if @drawing<>nil then
                  if drawing.pcamera<>nil then
                  begin
                       drawing.pcamera^.prop.point.y:=-strtofloat(s);
                  end;
              end;
           13:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_Snap<>nil then
                  begin
                       sysvar.DWG.DWG_Snap^.Base.x:=strtofloat(s);
                  end;
              end;
           23:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_Snap<>nil then
                  begin
                       sysvar.DWG.DWG_Snap^.Base.y:=strtofloat(s);
                  end;
              end;
           14:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_Snap<>nil then
                  begin
                       sysvar.DWG.DWG_Snap^.Spacing.x:=strtofloat(s);
                  end;
              end;
           24:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_Snap<>nil then
                  begin
                       sysvar.DWG.DWG_Snap^.Spacing.y:=strtofloat(s);
                  end;
              end;
           15:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_GridSpacing<>nil then
                  begin
                       sysvar.DWG.DWG_GridSpacing^.x:=strtofloat(s);
                  end;
              end;
           25:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_GridSpacing<>nil then
                  begin
                       sysvar.DWG.DWG_GridSpacing^.y:=strtofloat(s);
                  end;
              end;
           40:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if @drawing<>nil then
                  if drawing.pcamera<>nil then
                  if drawing.wa.getviewcontrol<>nil then
                  begin
                       drawing.pcamera^.prop.zoom:=(strtofloat(s)/drawing.wa.getviewcontrol.ClientHeight);
                  end;
              end;
           41:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if @drawing<>nil then
                  if drawing.pcamera<>nil then
                  if drawing.wa.getviewcontrol<>nil then
                  begin
                       if drawing.wa.getviewcontrol.ClientHeight*strtofloat(s)>drawing.wa.getviewcontrol.ClientWidth then
                       drawing.pcamera^.prop.zoom:=drawing.pcamera^.prop.zoom*strtofloat(s)*drawing.wa.getviewcontrol.ClientHeight/drawing.wa.getviewcontrol.ClientWidth;
                  end;
              end;
           71:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if @drawing<>nil then
                  if drawing.wa.getviewcontrol<>nil then
                  begin
                       flags:=strtoint(s);
                       if (flags and 1)<>0 then
                                     drawing.wa.param.projtype:=PROJPerspective
                                 else
                                     drawing.wa.param.projtype:=PROJParalel;
                  end;
             end;
           75:
             begin
                  if LoadMode=TLOLoad then
                  if active then
                  if sysvar.DWG.DWG_SnapGrid<>nil then
                  begin
                       if s<>'0' then
                                     sysvar.DWG.DWG_SnapGrid^:=true
                                 else
                                     sysvar.DWG.DWG_SnapGrid^:=false;
                  end;
             end;
         76:
           begin
                if LoadMode=TLOLoad then
                if active then
                if sysvar.DWG.DWG_DrawGrid<>nil then
                begin
                     if s<>'0' then
                                   sysvar.DWG.DWG_DrawGrid^:=true
                               else
                                   sysvar.DWG.DWG_DrawGrid^:=false;
                end;
            end;
       end;

     end;
     end;
     programlog.logoutstr('end;{ReadVport}',lp_DecPos,LM_Debug);
end;
procedure ReadDimStyles(var s:string;cdimstyle:string;var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing;var h2p:TMapHandleToPointer);
var
   psimstyleprop:PGDBDimStyle;
   byt:integer;
   ReadDimStylesMode:TDimStyleReadMode;
begin
if GoToDXForENDTAB(f, 0, dxfName_DIMSTYLE) then
while s = dxfName_DIMSTYLE do
begin
     psimstyleprop:=nil;
     ReadDimStylesMode:=TDSRM_ACAD;
     byt := 2;
     while byt <> 0 do
     begin
     s := f.readGDBString;
     byt := strtoint(s);
     s := f.readGDBString;


     if psimstyleprop=nil then
     begin
           if byt=2 then
                         begin
                              psimstyleprop:=drawing.DimStyleTable.MergeItem(s,LoadMode);
                              if psimstyleprop<>nil then
                                                        psimstyleprop^.init(s);
                              if uppercase(s)=uppercase(cdimstyle)then
                              if (sysvar.DWG.DWG_CTStyle<>nil)and(LoadMode=TLOLoad) then
                                                                                        sysvar.DWG.DWG_CDimStyle^:=psimstyleprop;
                         end;
     end
     else
         psimstyleprop^.SetValueFromDxf(ReadDimStylesMode,byt,s,h2p);
     end;
end;
end;
procedure ReadBlockRecird(const Handle2BlockName:TMapBlockHandle_BlockNames;var s:string;var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing);
var
   byt:integer;
   bname:string;
   bhandle:TDWGHandle;
begin
while s = dxfName_BLOCKRECORD do
begin
     byt := 2;
     while byt <> 0 do
     begin
     s := f.readGDBString;
     byt := strtoint(s);
     s := f.readGDBString;
     if byt=2 then
                  begin
                       bname:=s;
                       Handle2BlockName.Insert(bhandle,bname);
                  end;
     if byt=5 then
                  begin
                       bhandle:=DXFHandle(s);
                  end;
     end;
end;
end;

procedure addfromdxf2000(var f:GDBOpenArrayOfByte; exitGDBString: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing;h2p:TMapHandleToPointer;DWGVarsDict:TGDBString2GDBStringDictionary);
var
  byt: GDBInteger;
  error: GDBInteger;
  s,US, sname: String;
  tp: PGDBObjBlockdef;
  blockload:boolean;

  clayer,cdimstyle,cltype,ctstyle:GDBString;
  Handle2BlockName:TMapBlockHandle_BlockNames;
begin
  {$IFNDEF DELPHI}
  Handle2BlockName:=TMapBlockHandle_BlockNames.Create;
  {$ENDIF}
  blockload:=false;
  programlog.LogOutStr('AddFromDXF2000',lp_IncPos,LM_Debug);
  readvariables(f,ctstyle,clayer,cltype,cdimstyle,LoadMode,DWGVarsDict);
  repeat
    gotodxf(f, 0, dxfName_SECTION);
    if not f.notEOF then
      system.break;
    s := f.readGDBString;
    s := f.readGDBString;
    if s = dxfName_TABLES then
    begin
      if not f.notEOF then
        system.break;
      s := f.readGDBString;
      s := f.readGDBString;
      while s = dxfName_TABLE do
      begin
        if not f.notEOF then
          system.break;
        s := f.readGDBString;
        s := f.readGDBString;

        case s of
                    dxfName_CLASSES:
                                    gotodxf(f, 0, dxfName_ENDTAB);//scip this table
                      dxfName_APPID:
                                    gotodxf(f, 0, dxfName_ENDTAB);//scip this table
               dxfName_BLOCK_RECORD:
                                    begin
                                    programlog.LogOutStr('Found BLOCK_RECORD table',lp_IncPos,LM_Debug);
                                    ReadBlockRecird(Handle2BlockName,s,f,exitGDBString,owner,LoadMode,drawing);
                                    programlog.LogOutStr('end; {BLOCK_RECORD table}',lp_DecPos,LM_Debug);
                                    end;
                   dxfName_DIMSTYLE:
                                    begin
                                      programlog.LogOutStr('Found dimstyles table',lp_IncPos,LM_Debug);
                                      ReadDimStyles(s,cdimstyle,f,exitGDBString,owner,LoadMode,drawing,h2p);
                                      programlog.LogOutStr('end; {dimstyles table}',lp_DecPos,LM_Debug);
                                    end;
                      dxfName_Layer:
                                    begin
                                      programlog.LogOutStr('Found layer table',lp_IncPos,LM_Debug);
                                      ReadLayers(s,clayer,f,exitGDBString,owner,LoadMode,drawing);
                                      programlog.LogOutStr('end; {layer table}',lp_DecPos,LM_Debug);
                                    end;
                      dxfName_LType:
                                    begin
                                      programlog.LogOutStr('Found line types table',lp_IncPos,LM_Debug);
                                      ReadLTStyles(s,cltype,f,exitGDBString,owner,LoadMode,drawing,h2p);
                                      programlog.LogOutStr('end; (line types table)',lp_DecPos,LM_Debug);
                                    end;
                      dxfName_Style:
                                    begin
                                      programlog.LogOutStr('Found style table',lp_IncPos,LM_Debug);
                                      ReadTextstyles(s,ctstyle,f,exitGDBString,owner,LoadMode,drawing,h2p);
                                      programlog.LogOutStr('end; {style table}',lp_DecPos,LM_Debug);
                                    end;
                              'UCS':
                                    gotodxf(f, 0, dxfName_ENDTAB);//scip this table
                             'VIEW':
                                    gotodxf(f, 0, dxfName_ENDTAB);//scip this table
                            'VPORT':
                                    begin
                                    programlog.LogOutStr('Found vports table',lp_IncPos,LM_Debug);
                                    ReadVport(s,f,exitGDBString,owner,LoadMode,drawing);
                                    programlog.LogOutStr('end; {vports table}',lp_DecPos,LM_Debug);
                                    end;
        end;{case}
        s := f.readGDBString;
        s := f.readGDBString;
      end;

    end
    else
      if s = 'ENTITIES' then
      begin
        programlog.LogOutStr('Found entities section',lp_IncPos,LM_Debug);
        //inc(foc);
        {addfromdxf12}addentitiesfromdxf(f, dxfName_ENDSEC,owner,drawing,h2p);
        owner^.ObjArray.pack;
        owner^.correctobjects(nil,0);
        //inc(foc);
        programlog.LogOutStr('end; {vports table}',lp_DecPos,LM_Debug);
      end
      else
        if s = 'BLOCKS' then
        begin
          programlog.LogOutStr('Found block table',lp_IncPos,LM_Debug);
          sname := '';
          repeat
            US:=uppercase(s);
            if (sname = '  2') or (sname = '2') then
              if (pos('MODEL_SPACE',US)<>0)or(pos('PAPER_SPACE',US)<>0)or(pos('*A',US)=1)or(pos('*D',US)=1){or(pos('*U',US)=1)}then   //блоки *U игнорировать нестоит, что то связанное с параметризацией
              begin
                //programlog.logoutstr('Ignored block '+s+';',lp_OldPos);
                shared.HistoryOutStr(format(rsBlockIgnored,[s]));
                while (s <> 'ENDBLK') do
                  s := f.readGDBString;
              end
              else if drawing.BlockDefArray.getindex(s)>=0 then
                               begin
                                    //programlog.logoutstr('Ignored double definition block '+s+';',lp_OldPos);
                                    shared.HistoryOutStr(format(rsDoubleBlockIgnored,[s]));
                                    if s='DEVICE_PS_UK-VK'then
                                               s:=s;
                                    while (s <> 'ENDBLK') do
                                    s := f.readGDBString;
                               end
              else begin
                   if s='polyline' then
                                  s:=s;

                tp := drawing.BlockDefArray.create(s);
                programlog.LogOutFormatStr('Found blockdef "%s"',[s],lp_IncPos,LM_Info);
                   //addfromdxf12(f, GDBPointer(GDB.pgdbblock^.blockarray[GDB.pgdbblock^.count].ppa),@tp^.Entities, 'ENDBLK');
                while (s <> ' 30') and (s <> '30') do
                begin
                  s := f.readGDBString;
                  val(s, byt, error);
                  case byt of
                    10:
                      begin
                        s := f.readGDBString;
                        tp^.Base.x := strtofloat(s);
                      end;
                    20:
                      begin
                        s := f.readGDBString;
                        tp^.Base.y := strtofloat(s);
                      end;
                  end;
                end;
                s := f.readGDBString;
                tp^.Base.z := strtofloat(s);
                programlog.LogOutFormatStr('Base x:%g y:%g z:%g',[tp^.Base.x,tp^.Base.y,tp^.Base.z],lp_OldPos,LM_Info);
                inc(foc);
                AddEntitiesFromDXF(f,'ENDBLK',tp,drawing,h2p);
                dec(foc);
                if tp^.name='TX' then
                                                           tp^.name:=tp^.name;
                tp^.LoadFromDXF(f,nil,drawing);
                blockload:=true;
                programlog.LogOutStr('end block;',lp_DecPos,LM_Info);
                sname:='##'
              end;
            if not blockload then
                                 sname := f.readGDBString;
            blockload:=false;
            s := f.readGDBString;
          until (s = dxfName_ENDSEC);
          programlog.LogOutStr('end; {block table}',lp_DecPos,LM_Debug);
          drawing.BlockDefArray.Format;
          drawing.DimStyleTable.ResolveDXFHandles(Handle2BlockName);
          drawing.DimStyleTable.ResolveLineTypes(drawing.LTypeStyleTable);
        end;

    s := s;
//       if (byt=fcode) and (s=fname) then exit;
    if assigned(ProcessLongProcessProc)then
    ProcessLongProcessProc(f.ReadPos);
  until not f.notEOF;
  {$IFNDEF DELPHI}
  Handle2BlockName.destroy;
  {$ENDIF}
  programlog.LogOutStr('end; {AddFromDXF2000}',lp_DecPos,LM_Debug);
end;

procedure addfromdxf(name: GDBString;owner:PGDBObjGenericSubEntry;LoadMode:TLoadOpt;var drawing:TSimpleDrawing);
var
  f: GDBOpenArrayOfByte;
  s,s1,s2: GDBString;
  dxfversion,code:integer;
  h2p:TMapHandleToPointer;
  DWGVarsDict:TGDBString2GDBStringDictionary;
begin
  programlog.LogOutFormatStr('AddFromDXF("%s")',[name],lp_IncPos,LM_Debug);
  shared.HistoryOutStr(format(rsLoadingFile,[name]));
  f.InitFromFile(name);
  if f.Count<>0 then
  begin
     DWGVarsDict:=TGDBString2GDBStringDictionary.create;
     ReadDXFHeader(f,DWGVarsDict);
     h2p:=TMapHandleToPointer.create;

  if assigned(StartLongProcessProc)then
    StartLongProcessProc(f.Count,'Load DXF file');

    if DWGVarsDict.mygetvalue('$ACADVER',s) then
      begin
        s1:=copy(s,3,length(s)-2);
        s2:=copy(s,1,2);
        val(s1,dxfversion,code);

        if (uppercase(s2)='AC')and(code=0)then
        begin
             case dxfversion of
                               1009:begin
                                         shared.HistoryOutStr(format(rsFileFormat,['DXF12 ('+s+')']));
                                         gotodxf(f, 0, dxfName_ENDSEC);
                                         addfromdxf12(f,'EOF',owner,loadmode,drawing);
                                    end;
                               1015:begin
                                         shared.HistoryOutStr(format(rsFileFormat,['DXF2000 ('+s+')']));
                                         addfromdxf2000(f,'EOF',owner,loadmode,drawing,h2p,DWGVarsDict)
                                    end;
                               1018:begin
                                         shared.HistoryOutStr(format(rsFileFormat,['DXF2004 ('+s+')']));
                                         addfromdxf2000(f,'EOF',owner,loadmode,drawing,h2p,DWGVarsDict)
                                    end;
                               1021:begin
                                         shared.HistoryOutStr(format(rsFileFormat,['DXF2007 ('+s+')']));
                                         addfromdxf2000(f,'EOF',owner,loadmode,drawing,h2p,DWGVarsDict)
                                    end;
                               1024:begin
                                         shared.HistoryOutStr(format(rsFileFormat,['DXF2010 ('+s+')']));
                                         addfromdxf2000(f,'EOF',owner,loadmode,drawing,h2p,DWGVarsDict)
                                    end;
                               else
                                       begin
                                            ShowError(rsUnknownFileFormat+' $ACADVER='+s);
                                       end;


             end;
        end
           else ShowError(rsUnknownFileFormat+' $ACADVER='+s);
      end;
  if assigned(EndLongProcessProc)then
    EndLongProcessProc;
  owner^.calcbb;
  h2p.Destroy;
  DWGVarsDict.destroy;
  //GDBFreeMem(GDBPointer(phandlearray));
  end
     else
         shared.ShowError('IODXF.ADDFromDXF: Не могу открыть файл: '+name);
  f.done;
  programlog.LogOutStr('end; {AddFromDXF}',lp_DecPos,LM_Debug);
end;
procedure saveentitiesdxf2000(pva: PGDBObjEntityOpenArray; var outhandle:{GDBInteger}GDBOpenArrayOfByte; var handle: TDWGHandle;const drawing:TSimpleDrawing);
var
//  i:GDBInteger;
  pv:pgdbobjEntity;
  ir:itrec;
begin

     pv:=pva^.beginiterate(ir);
     if pv<>nil then
     repeat
          if assigned(ProcessLongProcessProc)then
                                                 ProcessLongProcessProc(ir.itc);
          pv^.DXFOut(handle, outhandle,drawing);
     pv:=pva^.iterate(ir);
     until pv=nil;
end;

procedure RegisterAcadAppInDXF(appname:GDBSTRING; outstream: PGDBOpenArrayOfByte;var handle: TDWGHandle);
begin
  outstream^.TXTAddGDBStringEOL(dxfGroupCode(0));
  outstream^.TXTAddGDBStringEOL('APPID');

  outstream^.TXTAddGDBStringEOL(dxfGroupCode(5));
  outstream^.TXTAddGDBStringEOL(inttohex(handle, 0));
  inc(handle);

  outstream^.TXTAddGDBStringEOL(dxfGroupCode(100));
  outstream^.TXTAddGDBStringEOL('AcDbSymbolTableRecord');
  outstream^.TXTAddGDBStringEOL(dxfGroupCode(100));
  outstream^.TXTAddGDBStringEOL('AcDbRegAppTableRecord');
  outstream^.TXTAddGDBStringEOL(dxfGroupCode(2));
  outstream^.TXTAddGDBStringEOL(appname);
  outstream^.TXTAddGDBStringEOL(dxfGroupCode(70));
  outstream^.TXTAddGDBStringEOL('0');
  {
  0
  APPID
  5
  12
  >>330
  >>9
  100
  AcDbSymbolTableRecord
  100
  AcDbRegAppTableRecord
  2
  ACAD
  70
  0
  }
end;
procedure MakeVariablesDict(VarsDict:TGDBString2GDBStringDictionary; var drawing:TSimpleDrawing);
var
   pcurrtextstyle:PGDBTextStyle;
begin
    VarsDict.insert('$CLAYER',drawing.LayerTable.GetCurrentLayer^.Name);
    VarsDict.insert('$CELTYPE',drawing.LTypeStyleTable.GetCurrentLType^.Name);

    pcurrtextstyle:=drawing.TextStyleTable.GetCurrentTextStyle;
    if pcurrtextstyle<>nil then
                               VarsDict.insert('$TEXTSTYLE',drawing.TextStyleTable.GetCurrentTextStyle^.Name)
                           else
                               VarsDict.insert('$TEXTSTYLE',TSNStandardStyleName);
    if assigned(drawing.DimStyleTable.GetCurrentDimStyle) then

    VarsDict.insert('DIMSTYLE',drawing.DimStyleTable.GetCurrentDimStyle^.Name)
  else
    VarsDict.insert('DIMSTYLE','Standatd');

    if assigned(sysvar.DWG.DWG_CLinew) then
                                           VarsDict.insert('$CELWEIGHT',inttostr(sysvar.DWG.DWG_CLinew^))
                                       else
                                           VarsDict.insert('$CELWEIGHT',inttostr(-1));

    if assigned(sysvar.DWG.DWG_LTScale) then
                                            VarsDict.insert('$LTSCALE',floattostr(sysvar.DWG.DWG_LTScale^))
                                        else
                                            VarsDict.insert('$LTSCALE',floattostr(1.0));

    if assigned(sysvar.DWG.DWG_CLTScale) then
                                             VarsDict.insert('$CELTSCALE',floattostr(sysvar.DWG.DWG_CLTScale^))
                                         else
                                             VarsDict.insert('$CELTSCALE',floattostr(1.0));

    if assigned(sysvar.DWG.DWG_CColor) then
                                           VarsDict.insert('$CECOLOR',inttostr(sysvar.DWG.DWG_CColor^))
                                       else
                                           VarsDict.insert('$CECOLOR',inttostr(256));


    if assigned(sysvar.DWG.DWG_DrawMode) then
                                             begin
                                                  if sysvar.DWG.DWG_DrawMode^ then
                                                                                  VarsDict.insert('$LWDISPLAY',inttostr(1))
                                                                              else
                                                                                  VarsDict.insert('$LWDISPLAY',inttostr(0));
                                             end
                                         else
                                             VarsDict.insert('$LWDISPLAY',inttostr(0));
   VarsDict.insert('$HANDSEED','FUCK OFF!');

   if assigned(sysvar.DWG.DWG_LUnits) then
                                        VarsDict.insert('$LUNITS',inttostr(ord(sysvar.DWG.DWG_LUnits^)+1));
   if assigned(sysvar.DWG.DWG_LUPrec) then
                                        VarsDict.insert('$LUPREC',inttostr(ord(sysvar.DWG.DWG_LUPrec^)));
   if assigned(sysvar.DWG.DWG_AUnits) then
                                        VarsDict.insert('$AUNITS',inttostr(ord(sysvar.DWG.DWG_AUnits^)));
   if assigned(sysvar.DWG.DWG_AUPrec) then
                                        VarsDict.insert('$AUPREC',inttostr(ord(sysvar.DWG.DWG_AUPrec^)));
   if assigned(sysvar.DWG.DWG_AngDir) then
                                        VarsDict.insert('$ANGDIR',inttostr(ord(sysvar.DWG.DWG_AngDir^)));
   if assigned(sysvar.DWG.DWG_AngBase) then
                                        VarsDict.insert('$ANGBASE',floattostr(sysvar.DWG.DWG_AngBase^));
   if assigned(sysvar.DWG.DWG_UnitMode) then
                                        VarsDict.insert('$UNITMODE',inttostr(ord(sysvar.DWG.DWG_UnitMode^)));
   if assigned(sysvar.DWG.DWG_InsUnits) then
                                           VarsDict.insert('$INSUNITS',inttostr(ord(sysvar.DWG.DWG_InsUnits^)));
   if assigned(sysvar.DWG.DWG_TextSize) then
                                           VarsDict.insert('$TEXTSIZE',floattostr(sysvar.DWG.DWG_TextSize^));
end;

function savedxf2000(name: GDBString; var drawing:TSimpleDrawing):boolean;
var
  templatefile: GDBOpenArrayOfByte;
  outstream: {GDBInteger}GDBOpenArrayOfByte;
  groups, values, ucvalues,ts: GDBString;
  groupi, valuei, intable,attr: GDBInteger;
  temphandle,temphandle2,temphandle3,temphandle4,handle,lasthandle,vporttablehandle,plottablefansdle,dimtablehandle: TDWGHandle;
  i: integer;
  OldHandele2NewHandle:TMapHandleToHandle;
  //phandlea: pdxfhandlerecopenarray;
  inlayertable, inblocksec, inblocktable, inlttypetable, indimstyletable, inappidtable: GDBBoolean;
  handlepos:integer;
  ignoredsource:boolean;
  instyletable:boolean;
  invporttable:boolean;
  olddwg:{PTDrawing}PTSimpleDrawing;
  pltp:PGDBLtypeProp;
  plp:PGDBLayerProp;
  pdsp:PGDBDimStyle;
  ir,ir2,ir3,ir4,ir5:itrec;
  TDI:PTDashInfo;
  PStroke:PGDBDouble;
  PSP:PShapeProp;
  PTP:PTextProp;
  p:pointer;
  {$IFNDEF DELPHI}
  Handle2pointer:TMapPointerToHandle;
  VarsDict:TGDBString2GDBStringDictionary;
  {$ENDIF}
  //DWGHandle:TDWGHandle;
  laststrokewrited:boolean;
  pcurrtextstyle:PGDBTextStyle;
  variablenotprocessed:boolean;
  processedvarscount:integer;
begin
  {$IFNDEF DELPHI}
  Handle2pointer:=TMapPointerToHandle.Create;
  VarsDict:=TGDBString2GDBStringDictionary.create;
  {$ENDIF}
  DecimalSeparator := '.';
  //standartstylehandle:=0;
  olddwg:=nil;//@drawing;
  if @SetCurrentDWGProc<>nil
                            then olddwg:=SetCurrentDWGProc(@drawing);
  //gdb.SetCurrentDWG(pdrawing);
  //--------------------------outstream := FileCreate(name);
  outstream.init({$IFDEF DEBUGBUILD}'{51453949-893A-49C2-9588-42B25346D071}',{$ENDIF}10*1024*1024);
  //--------------------------if outstream>0 then
  begin
    if assigned(StartLongProcessProc)then
  StartLongProcessProc({p}drawing.pObjRoot^.ObjArray.Count,'Save DXF file');
  OldHandele2NewHandle:=TMapHandleToHandle.Create;
  OldHandele2NewHandle.Insert(0,0);
  //phandlea := dxfhandlearraycreate(10000);
  //pushhandle(phandlea,0,0);
  templatefile.InitFromFile(sysparam.programpath + 'components/empty.dxf');
  handle := $2;
  inlayertable := false;
  inblocksec := false;
  inblocktable := false;
  instyletable := false;
  ignoredsource:=false;
  invporttable:=false;
  inlttypetable:=false;
  indimstyletable:=false;
  inappidtable:=false;
  MakeVariablesDict(VarsDict,drawing);
  processedvarscount:=VarsDict.size;
  while templatefile.notEOF do
  begin
    if  (templatefile.count-templatefile.ReadPos)<10
    then
        handle:=handle;
    groups := templatefile.readGDBString;
    values := templatefile.readGDBString;
    ucvalues:=uppercase(values);
    groupi := strtoint(groups);
    variablenotprocessed:=true;
    if (groupi = 9)and(processedvarscount>0) then
    begin
      variablenotprocessed:=false;
      if VarsDict.mygetvalue(values,ts) then
        begin
             outstream.TXTAddGDBStringEOL(groups);
             outstream.TXTAddGDBStringEOL(values);
             groups := templatefile.readGDBString;
             {values := }templatefile.readGDBString;
             outstream.TXTAddGDBStringEOL(groups);
             if values='$HANDSEED' then
                                       handlepos:=outstream.Count;
             outstream.TXTAddGDBStringEOL(ts);
             dec(processedvarscount);
        end
      else variablenotprocessed:=true;
    end
    {else};if variablenotprocessed then
      if (groupi = 5)
      or (groupi = 320)
      or (groupi = 330)
      or (groupi = 340)
      or (groupi = 350)
      or (groupi = 1005)
      or (groupi = 390)
      or (groupi = 360)
      or (groupi = 105) then
      begin
        valuei := strtoint('$' + values);
                          {if valuei<>0 then
                                       begin}
        if valuei=0 then
                        valuei:=0;
        if inlayertable and (groupi=390) then
                                             plottablefansdle:={handle-1}intable;  {поймать плоттабле}
        intable :=OldHandele2NewHandle.MyGetValue(valuei);
        //intable :=GetNewHandle(valuei);
        //intable := {}getnevhandle(phandlea, valuei){}{valuei};
        if {}intable >0{}{true} then
        begin
          if not ignoredsource then
          begin
          outstream.TXTAddGDBStringEOL(groups);
          outstream.TXTAddGDBStringEOL(inttohex(intable, 0));
          end;
          lasthandle:=intable;
        end
        else
        begin
          OldHandele2NewHandle.Insert(valuei, handle);
          //pushhandle(phandlea, valuei, handle);
          if not ignoredsource then
          begin
          outstream.TXTAddGDBStringEOL(groups);
          outstream.TXTAddGDBStringEOL(inttohex(handle, 0));
          end;
          lasthandle:=handle;
          inc(handle);
        end;
        if inlayertable and (groupi=390) then
                                             plottablefansdle:=lasthandle;  {поймать плоттабле}
        if indimstyletable and (groupi=5) then
                                             dimtablehandle:=lasthandle;  {поймать dimtable}
        (*{if instyletable and (groupi=5) then
                                             standartstylehandle:=lasthandle;{intable;}  {поймать standart}*)
      end
      else
        if (groupi = 2) and (values = 'ENTITIES') then
        begin
          outstream.TXTAddGDBStringEOL(groups);
          //WriteString_EOL(outstream, groups);
          outstream.TXTAddGDBStringEOL(values);
          //WriteString_EOL(outstream, values);
          //historyoutstr('Entities start here_______________________________________________________');
          saveentitiesdxf2000(@{p}drawing.pObjRoot^.ObjArray, outstream, handle,drawing);
        end
        else
          if (groupi = 2) and (values = 'BLOCKS') then
          begin
            outstream.TXTAddGDBStringEOL(groups);
            outstream.TXTAddGDBStringEOL(values);
            //WriteString_EOL(outstream, groups);
            //WriteString_EOL(outstream, values);
            inblocksec := true;
          end
          else
            if (inblocksec) and ((groupi = 0) and (values = dxfName_ENDSEC)) then
            begin
              //historyoutstr('Blockdefs start here_______________________________________________________');
              if {p}drawing.BlockDefArray.count>0 then
              for i := 0 to {p}drawing.BlockDefArray.count - 1 do
              begin
                outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                outstream.TXTAddGDBStringEOL('BLOCK');

                //GetOrCreateHandle(@(PBlockdefArray(drawing.BlockDefArray.parray)^[i]),handle,temphandle);
                //
                outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                outstream.TXTAddGDBStringEOL(inttohex(handle{temphandle}, 0));
                inc(handle);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                outstream.TXTAddGDBStringEOL(dxfName_AcDbEntity);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(8));
                outstream.TXTAddGDBStringEOL('0');
                outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                outstream.TXTAddGDBStringEOL('AcDbBlockBegin');
                outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                outstream.TXTAddGDBStringEOL(PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].name);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
                outstream.TXTAddGDBStringEOL('2');
                outstream.TXTAddGDBStringEOL(dxfGroupCode(10));
                outstream.TXTAddGDBStringEOL(floattostr(PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].base.x));
                outstream.TXTAddGDBStringEOL(dxfGroupCode(20));
                outstream.TXTAddGDBStringEOL(floattostr(PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].base.y));
                outstream.TXTAddGDBStringEOL(dxfGroupCode(30));
                outstream.TXTAddGDBStringEOL(floattostr(PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].base.z));
                outstream.TXTAddGDBStringEOL(dxfGroupCode(3));
                outstream.TXTAddGDBStringEOL(PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].name);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(1));
                outstream.TXTAddGDBStringEOL('');

                saveentitiesdxf2000(@PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].ObjArray, outstream, handle,drawing);

                outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                outstream.TXTAddGDBStringEOL('ENDBLK');
                outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                outstream.TXTAddGDBStringEOL(inttohex(handle, 0));
                inc(handle);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                outstream.TXTAddGDBStringEOL(dxfName_AcDbEntity);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(8));
                outstream.TXTAddGDBStringEOL('0');
                outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                outstream.TXTAddGDBStringEOL('AcDbBlockEnd');
              end;

              outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
              outstream.TXTAddGDBStringEOL(dxfName_ENDSEC);


              inblocksec := false;
            end
            else if (invporttable) and ((groupi = 0) and (values = dxfName_ENDTAB)) then
            begin
               invporttable:=false;
               ignoredsource:=false;

               outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
               outstream.TXTAddGDBStringEOL(inttohex(handle,0));
               vporttablehandle:=handle;
               inc(handle);

               outstream.TXTAddGDBStringEOL(dxfGroupCode(330));
               outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
               outstream.TXTAddGDBStringEOL('AcDbSymbolTable');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
               outstream.TXTAddGDBStringEOL('1');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
               outstream.TXTAddGDBStringEOL('VPORT');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
               outstream.TXTAddGDBStringEOL(inttohex(handle,0));
               inc(handle);
               outstream.TXTAddGDBStringEOL(dxfGroupCode(330));
               outstream.TXTAddGDBStringEOL(inttohex(vporttablehandle,0));

               outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
               outstream.TXTAddGDBStringEOL('AcDbSymbolTableRecord');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
               outstream.TXTAddGDBStringEOL('AcDbViewportTableRecord');

               outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
               outstream.TXTAddGDBStringEOL('*Active');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
               outstream.TXTAddGDBStringEOL('0');

               outstream.TXTAddGDBStringEOL(dxfGroupCode(10));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(20));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(11));
               outstream.TXTAddGDBStringEOL('1.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(21));
               outstream.TXTAddGDBStringEOL('1.0');

               if assigned(drawing.wa)and(drawing.wa.getviewcontrol<>nil) then
                                                        begin
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(12));
                                                             outstream.TXTAddGDBStringEOL(floattostr(drawing.wa.param.CPoint.x));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(22));
                                                             outstream.TXTAddGDBStringEOL(floattostr(drawing.wa.param.CPoint.y));
                                                        end
                                                    else
                                                        begin
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(12));
                                                             outstream.TXTAddGDBStringEOL('0');
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(22));
                                                             outstream.TXTAddGDBStringEOL('0');
                                                        end;
               outstream.TXTAddGDBStringEOL(dxfGroupCode(13));
               outstream.TXTAddGDBStringEOL(floattostr(sysvar.DWG.DWG_Snap^.Base.x));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(23));
               outstream.TXTAddGDBStringEOL(floattostr(sysvar.DWG.DWG_Snap^.Base.y));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(14));
               outstream.TXTAddGDBStringEOL(floattostr(sysvar.DWG.DWG_Snap^.Spacing.x));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(24));
               outstream.TXTAddGDBStringEOL(floattostr(sysvar.DWG.DWG_Snap^.Spacing.y));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(15));
               outstream.TXTAddGDBStringEOL(floattostr(sysvar.DWG.DWG_GridSpacing^.x));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(25));
               outstream.TXTAddGDBStringEOL(floattostr(sysvar.DWG.DWG_GridSpacing^.y));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(16));
               outstream.TXTAddGDBStringEOL(floattostr(-drawing.pcamera^.prop.look.x));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(26));
               outstream.TXTAddGDBStringEOL(floattostr(-drawing.pcamera^.prop.look.y));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(36));
               outstream.TXTAddGDBStringEOL(floattostr(-drawing.pcamera^.prop.look.z));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(17));
               outstream.TXTAddGDBStringEOL(floattostr(0));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(27));
               outstream.TXTAddGDBStringEOL(floattostr(0));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(37));
               outstream.TXTAddGDBStringEOL(floattostr(0));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(40));
               if assigned(drawing.wa)and(drawing.wa.getviewcontrol<>nil) then
                                                        outstream.TXTAddGDBStringEOL(floattostr(drawing.wa.param.ViewHeight))
                                                    else
                                                        outstream.TXTAddGDBStringEOL(inttostr(500));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(41));
               if assigned(drawing.wa)and(drawing.wa.getviewcontrol<>nil) then
                                                        outstream.TXTAddGDBStringEOL(floattostr(drawing.wa.getviewcontrol.ClientWidth/drawing.wa.getviewcontrol.ClientHeight))
                                                    else
                                                        outstream.TXTAddGDBStringEOL(inttostr(1));
               outstream.TXTAddGDBStringEOL(dxfGroupCode(42));
               outstream.TXTAddGDBStringEOL('50.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(43));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(44));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(50));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(51));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(71));
               outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(72));
               outstream.TXTAddGDBStringEOL('1000');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(73));
               outstream.TXTAddGDBStringEOL('1');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
               outstream.TXTAddGDBStringEOL('3');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(75));
               if sysvar.DWG.DWG_SnapGrid<>nil then
                                                   begin
                                                        if sysvar.DWG.DWG_SnapGrid^ then
                                                                                        outstream.TXTAddGDBStringEOL('1')
                                                                                    else
                                                                                        outstream.TXTAddGDBStringEOL('0');
                                                   end
                                               else
                                                   outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(76));
               if sysvar.DWG.DWG_DrawGrid<>nil then
                                                     begin
                                                          if sysvar.DWG.DWG_DrawGrid^ then
                                                                                          outstream.TXTAddGDBStringEOL('1')
                                                                                      else
                                                                                          outstream.TXTAddGDBStringEOL('0');
                                                     end
                                                 else
                                                     outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(77));
               outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(78));
               outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(281));
               outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(65));
               outstream.TXTAddGDBStringEOL('1');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(110));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(120));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(130));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(111));
               outstream.TXTAddGDBStringEOL('1.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(121));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(131));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(112));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(122));
               outstream.TXTAddGDBStringEOL('1.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(132));
               outstream.TXTAddGDBStringEOL('0.0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(79));
               outstream.TXTAddGDBStringEOL('0');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(146));
               outstream.TXTAddGDBStringEOL('0.0');
               //outstream.TXTAddGDBStringEOL(dxfGroupCode(1001));
               //outstream.TXTAddGDBStringEOL('ACAD_NAV_VCDISPLAY');
               //outstream.TXTAddGDBStringEOL(dxfGroupCode(1070));
               //outstream.TXTAddGDBStringEOL('3');
               outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
               outstream.TXTAddGDBStringEOL('ENDTAB');

            end
            else if (inblocktable) and ((groupi = 0) and (values = dxfName_ENDTAB)) then
            begin
              inblocktable := false;
              if {p}drawing.BlockDefArray.count>0 then

              for i := 0 to {p}drawing.BlockDefArray.count - 1 do
              begin
                outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                outstream.TXTAddGDBStringEOL(dxfName_BLOCK_RECORD);

                Handle2pointer.MyGetOrCreateValue(@(PBlockdefArray(drawing.BlockDefArray.parray)^[i]),handle,temphandle);
                //GetOrCreateHandle(@(PBlockdefArray(drawing.BlockDefArray.parray)^[i]),handle,temphandle);

                outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                outstream.TXTAddGDBStringEOL(inttohex({handle}temphandle, 0));
                //inc(handle);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                outstream.TXTAddGDBStringEOL(dxfName_AcDbSymbolTableRecord);
                outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                outstream.TXTAddGDBStringEOL('AcDbBlockTableRecord');
                outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                outstream.TXTAddGDBStringEOL(PBlockdefArray({p}drawing.BlockDefArray.parray)^[i].name);

              end;
              outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
              outstream.TXTAddGDBStringEOL(dxfName_ENDTAB);
            end

            else
              if (inlayertable) and ((groupi = 0) and (values = dxfName_ENDTAB)) then
              begin
                inlayertable := false;
                ignoredsource:=false;
                plp:=drawing.layertable.beginiterate(ir);
                if plp<>nil then
                repeat
                //for i := 0 to drawing.layertable.count - 1 do
                begin
                  //if PGDBLayerPropArray(gdb.GetCurrentDWG.layertable.parray)^[pltp].name <> '0' then
                  begin
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                    outstream.TXTAddGDBStringEOL(dxfName_Layer);
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                    outstream.TXTAddGDBStringEOL(inttohex(handle, 0));
                    inc(handle);
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                    outstream.TXTAddGDBStringEOL(dxfName_AcDbSymbolTableRecord);
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                    outstream.TXTAddGDBStringEOL('AcDbLayerTableRecord');
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                    outstream.TXTAddGDBStringEOL(plp^.name);
                    attr:=0;
                    if plp^._lock then
                                     attr:=attr + 4;
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
                    outstream.TXTAddGDBStringEOL(inttostr(attr));
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(62));
                    if plp^._on
                     then
                         outstream.TXTAddGDBStringEOL(inttostr(plp^.color))
                     else
                         outstream.TXTAddGDBStringEOL(inttostr(-plp^.color));
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(6));
                    outstream.TXTAddGDBStringEOL(GetLTName(plp^.LT));
                    {if assigned(plp^.LT) then
                                             outstream.TXTAddGDBStringEOL(PGDBLtypeProp(plp^.LT)^.Name)
                                         else
                                             outstream.TXTAddGDBStringEOL('Continuous');}
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(290));
                    if plp^._print then
                    //if uppercase(PGDBLayerPropArray(gdb.GetCurrentDWG.layertable.parray)^[pltp].name) <> 'DEFPOINTS' then
                      outstream.TXTAddGDBStringEOL('1')
                    else
                      outstream.TXTAddGDBStringEOL('0');
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(370));
                    outstream.TXTAddGDBStringEOL(inttostr(plp^.lineweight));
                    //WriteString_EOL(outstream, '-3');
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(390));
                    outstream.TXTAddGDBStringEOL(inttohex(plottablefansdle,0));

                    if plp^.desk<>''then
                    begin
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(1001));
                         outstream.TXTAddGDBStringEOL('AcAecLayerStandard');
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(1000));
                         outstream.TXTAddGDBStringEOL('');
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(1000));
                         outstream.TXTAddGDBStringEOL(plp^.desk);
                    end;
                  end;
                end;
                plp:=drawing.layertable.iterate(ir);
                until plp=nil;

                outstream.TXTAddGDBStringEOL(groups);
                outstream.TXTAddGDBStringEOL(values);
              end


            else
              if (inlttypetable) and ((groupi = 0) and (values = dxfName_ENDTAB)) then
              begin
                   inlttypetable := false;
                   ignoredsource:=false;
                   temphandle:=handle-1;
                   pltp:=drawing.LTypeStyleTable.beginiterate(ir);
                   if pltp<>nil then
                   repeat
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                         outstream.TXTAddGDBStringEOL(dxfName_LTYPE);
                         Handle2pointer.MyGetOrCreateValue(pltp,handle,temphandle);
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                         outstream.TXTAddGDBStringEOL(inttohex(temphandle, 0));
                         {outstream.TXTAddGDBStringEOL(inttohex(handle, 0));
                         inc(handle);}
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(330));
                         outstream.TXTAddGDBStringEOL(inttohex(temphandle, 0));
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                         outstream.TXTAddGDBStringEOL(dxfName_AcDbSymbolTableRecord);
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                         outstream.TXTAddGDBStringEOL('AcDbLinetypeTableRecord');
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                         outstream.TXTAddGDBStringEOL(pltp^.Name);
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
                         outstream.TXTAddGDBStringEOL('0');
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(3));
                         outstream.TXTAddGDBStringEOL(pltp^.desk);
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(72));
                         outstream.TXTAddGDBStringEOL('65');
                         i:=pltp^.strokesarray.GetRealCount;
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(73));
                         outstream.TXTAddGDBStringEOL(inttostr(i));
                         outstream.TXTAddGDBStringEOL(dxfGroupCode(40));
                         outstream.TXTAddGDBStringEOL(floattostr(pltp^.len));
                         if i>0 then
                         begin
                              TDI:=pltp^.dasharray.beginiterate(ir2);
                              PStroke:=pltp^.strokesarray.beginiterate(ir3);
                              PSP:=pltp^.shapearray.beginiterate(ir4);
                              PTP:=pltp^.textarray.beginiterate(ir5);
                              laststrokewrited:=false;
                              if PStroke<>nil then
                              repeat
                                    case TDI^ of
                                                TDIDash:begin
                                                             if laststrokewrited then
                                                                                     begin
                                                                                     outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
                                                                                     outstream.TXTAddGDBStringEOL('0');
                                                                                     end;
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(49));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PStroke^));
                                                             {outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
                                                             outstream.TXTAddGDBStringEOL('0');}
                                                             PStroke:=pltp^.strokesarray.iterate(ir3);
                                                             laststrokewrited:=true;
                                                        end;
                                               TDIShape:if (PSP^.Psymbol<>nil)and(PSP^.param.PStyle<>nil) then
                                                        begin
                                                             laststrokewrited:=false;
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
                                                             outstream.TXTAddGDBStringEOL('4');
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(75));
                                                             outstream.TXTAddGDBStringEOL(inttostr(PSP^.Psymbol^.number));

                                                             Handle2pointer.MyGetOrCreateValue(PSP^.param.PStyle,handle,temphandle);
                                                             //GetOrCreateHandle(PSP^.param.PStyle,handle,temphandle);

                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(340));
                                                             outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(46));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PSP^.param.Height));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(50));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PSP^.param.Angle));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(44));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PSP^.param.X));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(45));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PSP^.param.Y));
                                                             PSP:=pltp^.shapearray.iterate(ir4);
                                                        end;
                                               TDIText:begin
                                                             laststrokewrited:=false;
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
                                                             outstream.TXTAddGDBStringEOL('2');
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(75));
                                                             outstream.TXTAddGDBStringEOL('0');

                                                             Handle2pointer.MyGetOrCreateValue(PTP^.param.PStyle,handle,temphandle);
                                                             //GetOrCreateHandle(PTP^.param.PStyle,handle,temphandle);

                                                             {else
                                                                 temphandle:=standartstylehandle;}
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(340));
                                                             outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(46));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PTP^.param.Height));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(50));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PTP^.param.Angle));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(44));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PTP^.param.X));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(45));
                                                             outstream.TXTAddGDBStringEOL(floattostr(PTP^.param.Y));
                                                             outstream.TXTAddGDBStringEOL(dxfGroupCode(9));
                                                             outstream.TXTAddGDBStringEOL(PTP^.TEXT);
                                                             PTP:=pltp^.textarray.iterate(ir4);
                                                        end;
                                    end;
                                    TDI:=pltp^.dasharray.iterate(ir2);
                              until {PStroke}TDI=nil;
                              if laststrokewrited then
                                                       begin
                                                       outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
                                                       outstream.TXTAddGDBStringEOL('0');
                                                       end;

                         end;


                         pltp:=drawing.LTypeStyleTable.iterate(ir);
                   until pltp=nil;
                   outstream.TXTAddGDBStringEOL(groups);
                   outstream.TXTAddGDBStringEOL(values);
              end
            else
              if (indimstyletable) and ((groupi = 0) and (values = dxfName_ENDTAB)) then
              begin
                { TODO :  надо писать заголовок таблицы руками, а не из шаблона DXF, т.к. там есть перечень стилей который проебывается}
                indimstyletable:=false;
                ignoredsource:=false;
                temphandle3:=handle-1;
                temphandle4:=handle-3;
                //дальше идут стили
                pdsp:=drawing.DimStyleTable.beginiterate(ir);
                if pdsp<>nil then
                repeat
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                      outstream.TXTAddGDBStringEOL('DIMSTYLE');
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(105));
                      outstream.TXTAddGDBStringEOL(inttohex({temphandle3}handle, 0));
                      inc(handle);

                      outstream.TXTAddGDBStringEOL(dxfGroupCode(330));
                      outstream.TXTAddGDBStringEOL(inttohex({temphandle4}{temphandle3}dimtablehandle, 0));

                      outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                      outstream.TXTAddGDBStringEOL('AcDbSymbolTableRecord');
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                      outstream.TXTAddGDBStringEOL('AcDbDimStyleTableRecord');
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                      outstream.TXTAddGDBStringEOL(pdsp^.Name);
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(3));
                      outstream.TXTAddGDBStringEOL(pdsp^.Units.DIMPOST);
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
                      outstream.TXTAddGDBStringEOL('0');

                      //тут сами настройки
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(44));
                      outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Lines.DIMEXE));
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(42));
                      outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Lines.DIMEXO));
                      outstream.TXTAddGDBStringEOL(dxfGroupCode(46));
                      outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Lines.DIMDLE));

                      outstream.TXTAddGDBStringEOL(dxfGroupCode(41));
                      outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Arrows.DIMASZ));

                      outstream.TXTAddGDBStringEOL(dxfGroupCode(173));
                      if pdsp^.Arrows.DIMBLK1<>pdsp^.Arrows.DIMBLK2 then
                                                                        begin
                                                                             outstream.TXTAddGDBStringEOL('1');
                                                                         end
                                           else
                                               begin
                                                    outstream.TXTAddGDBStringEOL('0');
                                               end;

                      if pdsp^.Arrows.DIMLDRBLK<>TSClosedFilled then
                      begin
                           Handle2pointer.MyGetOrCreateValue(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(-1).name),handle,temphandle);
                           //GetOrCreateHandle(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(-1).name),handle,temphandle);
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(341));
                           outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                      end;


                      if pdsp^.Arrows.DIMBLK1<>pdsp^.Arrows.DIMBLK2 then
                                                                        begin
                                                                             if pdsp^.Arrows.DIMBLK1<>TSClosedFilled then
                                                                             begin
                                                                                   Handle2pointer.MyGetOrCreateValue(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(0).name),handle,temphandle);
                                                                                   //GetOrCreateHandle(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(0).name),handle,temphandle);
                                                                                   if temphandle<>0 then
                                                                                   begin
                                                                                         outstream.TXTAddGDBStringEOL(dxfGroupCode(343));
                                                                                         outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                                                                                   end;
                                                                             end;
                                                                             if pdsp^.Arrows.DIMBLK2<>TSClosedFilled then
                                                                             begin
                                                                                   Handle2pointer.MyGetOrCreateValue(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(1).name),handle,temphandle);
                                                                                   //GetOrCreateHandle(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(1).name),handle,temphandle);
                                                                                   if temphandle<>0 then
                                                                                   begin
                                                                                         outstream.TXTAddGDBStringEOL(dxfGroupCode(344));
                                                                                         outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                                                                                   end;
                                                                             end;
                                                                         end
                                           else
                                               begin
                                                    if pdsp^.Arrows.DIMBLK1<>TSClosedFilled then
                                                    begin
                                                    temphandle:=Handle2pointer.MyGetValue(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(0).name));
                                                    //GetHandle(drawing.BlockDefArray.getblockdef(pdsp^.GetDimBlockParam(0).name),temphandle);
                                                    if temphandle<>0 then
                                                    begin
                                                    outstream.TXTAddGDBStringEOL(dxfGroupCode(342));
                                                    outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                                                    end;
                                                    end;
                                               end;

                      //GetOrCreateHandle(@(PBlockdefArray(drawing.BlockDefArray.parray)^[i]),handle,temphandle);

                       (*
                       TGDBDimArrowsProp=packed record
                                              DIMBLK1:TArrowStyle;//First arrow block name//group343
                                              DIMBLK2:TArrowStyle;//First arrow block name//group344
                                              DIMLDRBLK:TArrowStyle;//Arrow block name for leaders//group341
                                         end;
                       *)
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(140));
                       outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Text.DIMTXT));

                       outstream.TXTAddGDBStringEOL(dxfGroupCode(141));
                       outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Lines.DIMCEN));

                       outstream.TXTAddGDBStringEOL(dxfGroupCode(73));
                       if pdsp^.Text.DIMTIH then
                                                outstream.TXTAddGDBStringEOL('1')
                                            else
                                                outstream.TXTAddGDBStringEOL('0');
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(74));
                       if pdsp^.Text.DIMTOH then
                                                outstream.TXTAddGDBStringEOL('1')
                                            else
                                                outstream.TXTAddGDBStringEOL('0');
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(147));
                       outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Text.DIMGAP));

                       outstream.TXTAddGDBStringEOL(dxfGroupCode(77));
                       case pdsp^.Text.DIMTAD of
                                  DTVPCenters:outstream.TXTAddGDBStringEOL('0');
                                    DTVPAbove:outstream.TXTAddGDBStringEOL('1');
                                  DTVPOutside:outstream.TXTAddGDBStringEOL('2');
                                      DTVPJIS:outstream.TXTAddGDBStringEOL('3');
                                   DTVPBellov:outstream.TXTAddGDBStringEOL('4');
                       end;{case}

                       outstream.TXTAddGDBStringEOL(dxfGroupCode(144));
                       outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Units.DIMLFAC));
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(271));
                       outstream.TXTAddGDBStringEOL(inttostr(pdsp^.Units.DIMDEC));
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(45));
                       outstream.TXTAddGDBStringEOL(floattostr(pdsp^.Units.DIMRND));

                       outstream.TXTAddGDBStringEOL(dxfGroupCode(277));
                       case pdsp^.Units.DIMLUNIT of
                                   DUScientific:outstream.TXTAddGDBStringEOL('1');
                                      DUDecimal:outstream.TXTAddGDBStringEOL('2');
                                  DUEngineering:outstream.TXTAddGDBStringEOL('3');
                                DUArchitectural:outstream.TXTAddGDBStringEOL('4');
                                   DUFractional:outstream.TXTAddGDBStringEOL('5');
                                       DUSystem:outstream.TXTAddGDBStringEOL('6');
                       end;{case}
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(278));
                       case pdsp^.Units.DIMDSEP of
                                   DDSDot:outstream.TXTAddGDBStringEOL('46');
                                 DDSComma:outstream.TXTAddGDBStringEOL('44');
                                 DDSSpace:outstream.TXTAddGDBStringEOL('32');
                       end;{case}
                       outstream.TXTAddGDBStringEOL(dxfGroupCode(279));
                       case pdsp^.Placing.DIMTMOVE of
                                   DTMMoveDimLine:outstream.TXTAddGDBStringEOL('0');
                                 DTMCreateLeader:outstream.TXTAddGDBStringEOL('1');
                                 DTMnothung:outstream.TXTAddGDBStringEOL('2');
                       end;{case}

                       if pdsp^.Lines.DIMLWD<>LnWtByLayer then
                       begin
                        //dxfGDBIntegerout(outhandle,371,pdsp^.Lines.DIMLWD);
                        outstream.TXTAddGDBStringEOL(dxfGroupCode(371));
                        outstream.TXTAddGDBStringEOL(inttostr(pdsp^.Lines.DIMLWD));
                       end;
                       if pdsp^.Lines.DIMLWE<>LnWtByLayer then
                       begin
                        //dxfGDBIntegerout(outhandle,372,pdsp^.Lines.DIMLWE);
                        outstream.TXTAddGDBStringEOL(dxfGroupCode(372));
                        outstream.TXTAddGDBStringEOL(inttostr(pdsp^.Lines.DIMLWE));
                       end;

                       if pdsp^.Lines.DIMCLRD<>ClByLayer then
                       begin
                        outstream.TXTAddGDBStringEOL(dxfGroupCode(176));
                        outstream.TXTAddGDBStringEOL(inttostr(pdsp^.Lines.DIMCLRD));
                       end;
                       if pdsp^.Lines.DIMCLRE<>ClByLayer then
                       begin
                        outstream.TXTAddGDBStringEOL(dxfGroupCode(177));
                        outstream.TXTAddGDBStringEOL(inttostr(pdsp^.Lines.DIMCLRE));
                       end;
                       if pdsp^.Text.DIMCLRT<>ClByLayer then
                       begin
                        outstream.TXTAddGDBStringEOL(dxfGroupCode(178));
                        outstream.TXTAddGDBStringEOL(inttostr(pdsp^.Text.DIMCLRT));
                       end;



                      outstream.TXTAddGDBStringEOL(dxfGroupCode(340));
                      p:=pdsp^.Text.DIMTXSTY{drawing.TextStyleTable.FindStyle('Standard',false)};

                      Handle2pointer.MyGetOrCreateValue(p,handle,temphandle);
                      //GetOrCreateHandle(p,handle,temphandle);

                      outstream.TXTAddGDBStringEOL(inttohex(temphandle, 0));

                      pltp:=drawing.LTypeStyleTable.GetSystemLT(TLTByBlock);
                      if (pdsp^.Lines.DIMLTYPE<>pltp)and(pdsp^.Lines.DIMLTYPE<>nil)then
                      begin
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1001));
                           outstream.TXTAddGDBStringEOL('ACAD_DSTYLE_DIM_LINETYPE');
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1070));
                           outstream.TXTAddGDBStringEOL('380');
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1005));
                           Handle2pointer.MyGetOrCreateValue(pdsp^.Lines.DIMLTYPE,handle,temphandle);
                           outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                      end;
                      if (pdsp^.Lines.DIMLTEX1<>pltp)and(pdsp^.Lines.DIMLTEX1<>nil)then
                      begin
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1001));
                           outstream.TXTAddGDBStringEOL('ACAD_DSTYLE_DIM_EXT1_LINETYPE');
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1070));
                           outstream.TXTAddGDBStringEOL('381');
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1005));
                           Handle2pointer.MyGetOrCreateValue(pdsp^.Lines.DIMLTEX1,handle,temphandle);
                           outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                      end;
                      if (pdsp^.Lines.DIMLTEX2<>pltp)and(pdsp^.Lines.DIMLTEX2<>nil)then
                      begin
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1001));
                           outstream.TXTAddGDBStringEOL('ACAD_DSTYLE_DIM_EXT2_LINETYPE');
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1070));
                           outstream.TXTAddGDBStringEOL('382');
                           outstream.TXTAddGDBStringEOL(dxfGroupCode(1005));
                           Handle2pointer.MyGetOrCreateValue(pdsp^.Lines.DIMLTEX2,handle,temphandle);
                           outstream.TXTAddGDBStringEOL(inttohex(temphandle,0));
                      end;

                      pdsp:=drawing.DimStyleTable.iterate(ir);
                until pdsp=nil;
                outstream.TXTAddGDBStringEOL(groups);
                outstream.TXTAddGDBStringEOL(values);
{0
DIMSTYLE
105
2EE
330
2ED
100
AcDbSymbolTableRecord
100
AcDbDimStyleTableRecord
  2
Standard
 70
     0
340
2DC
  0
ENDTAB}

              end
            else if (groupi = 0) and (values = dxfName_ENDTAB)and inappidtable then
                begin
                  inappidtable := false;
                  ignoredsource:=false;

                  RegisterAcadAppInDXF('ACAD',@outstream,handle);
                  RegisterAcadAppInDXF('ACAD_PSEXT',@outstream,handle);
                  RegisterAcadAppInDXF('AcAecLayerStandard',@outstream,handle);
                  RegisterAcadAppInDXF(ZCADAppNameInDXF,@outstream,handle);
                  //RegisterAcadAppInDXF('ACAD_NAV_VCDISPLAY',@outstream,handle);
                  RegisterAcadAppInDXF('ACAD_DSTYLE_DIM_LINETYPE',@outstream,handle);
                  RegisterAcadAppInDXF('ACAD_DSTYLE_DIM_EXT1_LINETYPE',@outstream,handle);
                  RegisterAcadAppInDXF('ACAD_DSTYLE_DIM_EXT2_LINETYPE',@outstream,handle);

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                  outstream.TXTAddGDBStringEOL('ENDTAB');
                end
            else
              if (instyletable) and ((groupi = 0) and (values = dxfName_ENDTAB)) then
              begin
                instyletable := false;
                ignoredsource:=false;
                temphandle2:=handle-2;
                if drawing.TextStyleTable.GetRealCount>0 then
                begin
                pcurrtextstyle:=drawing.TextStyleTable.beginiterate(ir);
                if pcurrtextstyle<>nil then
                //for i := 0 to drawing.TextStyleTable.count - 1 do
                repeat
                  //if PGDBLayerPropArray(gdb.GetCurrentDWG.layertable.parray)^[i].name <> '0' then
                  if {drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.UsedInLTYPE then
                  begin
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                  outstream.TXTAddGDBStringEOL(dxfName_Style);
                  p:={drawing.TextStyleTable.getelement(i))}pcurrtextstyle;

                  Handle2pointer.MyGetOrCreateValue({drawing.TextStyleTable.getelement(i))}pcurrtextstyle,handle,temphandle);
                  //GetOrCreateHandle(drawing.TextStyleTable.getelement(i),handle,temphandle);

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                  outstream.TXTAddGDBStringEOL(inttohex({handle}temphandle, 0));
                  inc(handle);
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(330));
                  outstream.TXTAddGDBStringEOL(inttohex(temphandle2, 0));
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                  outstream.TXTAddGDBStringEOL(dxfName_AcDbSymbolTableRecord);
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                  outstream.TXTAddGDBStringEOL('AcDbTextStyleTableRecord');
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                  outstream.TXTAddGDBStringEOL('');
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
                  outstream.TXTAddGDBStringEOL('1');

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(40));
                  outstream.TXTAddGDBStringEOL(floattostr({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.prop.size));

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(41));
                  outstream.TXTAddGDBStringEOL(floattostr({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.prop.wfactor));

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(50));
                  outstream.TXTAddGDBStringEOL(floattostr({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.prop.oblique));

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(71));
                  outstream.TXTAddGDBStringEOL('0');

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(42));
                  outstream.TXTAddGDBStringEOL('2.5');

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(3));
                  outstream.TXTAddGDBStringEOL({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.dxfname);

                  outstream.TXTAddGDBStringEOL(dxfGroupCode(4));
                  outstream.TXTAddGDBStringEOL('');

                  end
                  else
                  begin
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(0));
                    outstream.TXTAddGDBStringEOL(dxfName_Style);
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(5));
                    //if uppercase(PGDBTextStyle(drawing.TextStyleTable.getelement(i))^.name)<>TSNStandardStyleName then
                    begin
                    p:={drawing.TextStyleTable.getelement(i))}pcurrtextstyle;

                    Handle2pointer.MyGetOrCreateValue(p,handle,temphandle);
                    //GetOrCreateHandle(p,handle,temphandle);

                    outstream.TXTAddGDBStringEOL(inttohex(temphandle, 0));
                    //inc(handle);
                    end;
                    {else
                        outstream.TXTAddGDBStringEOL(inttohex(standartstylehandle, 0));}
                  outstream.TXTAddGDBStringEOL(dxfGroupCode(330));
                  outstream.TXTAddGDBStringEOL(inttohex(temphandle2, 0));
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                    outstream.TXTAddGDBStringEOL(dxfName_AcDbSymbolTableRecord);
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(100));
                    outstream.TXTAddGDBStringEOL('AcDbTextStyleTableRecord');
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(2));
                    outstream.TXTAddGDBStringEOL({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.name);
                    outstream.TXTAddGDBStringEOL(dxfGroupCode(70));
                    outstream.TXTAddGDBStringEOL('0');

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(40));
                    outstream.TXTAddGDBStringEOL(floattostr({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.prop.size));

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(41));
                    outstream.TXTAddGDBStringEOL(floattostr({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.prop.wfactor));

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(50));
                    outstream.TXTAddGDBStringEOL(floattostr({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.prop.oblique));

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(71));
                    outstream.TXTAddGDBStringEOL('0');

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(42));
                    outstream.TXTAddGDBStringEOL('2.5');

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(3));
                    outstream.TXTAddGDBStringEOL({drawing.TextStyleTable.getelement(i))}pcurrtextstyle^.dxfname);

                    outstream.TXTAddGDBStringEOL(dxfGroupCode(4));
                    outstream.TXTAddGDBStringEOL('');

                  end;
                pcurrtextstyle:=drawing.TextStyleTable.iterate(ir);
                until pcurrtextstyle=nil;
                end;
                outstream.TXTAddGDBStringEOL(groups);
                outstream.TXTAddGDBStringEOL(values);
              end


              else
                if (groupi = 0) and (values = dxfName_TABLE) then
                begin
                  outstream.TXTAddGDBStringEOL(groups);
                  outstream.TXTAddGDBStringEOL(values);
                  groups := templatefile.readGDBString;
                  values := templatefile.readGDBString;
                  groupi := strtoint(groups);
                  outstream.TXTAddGDBStringEOL(groups);
                  outstream.TXTAddGDBStringEOL(values);
                  if (groupi = 2) and (values = dxfName_Layer) then
                  begin
                    inlayertable := true;
                  end
                  else if (groupi = 2) and (values = dxfName_BLOCK_RECORD) then
                  begin
                    inblocktable := true;
                  end
                  else if (groupi = 2) and (values = dxfName_Style) then
                  begin
                    instyletable := true;
                  end
                  else if (groupi = 2) and (values = dxfName_LType) then
                  begin
                    inlttypetable := true;
                  end
                  else if (groupi = 2) and (values = 'DIMSTYLE') then
                  begin
                    indimstyletable := true;
                  end
                  else if (groupi = 2) and (values = 'APPID') then
                  begin
                    inappidtable := true;
                  end
                  else if (groupi = 2) and (values = 'VPORT') then
                  begin
                    invporttable := true;
                    IgnoredSource := true;
                  end;

                end

              else if (groupi = 0) and (values = dxfName_Layer)and inlayertable then
                  begin
                    IgnoredSource := true;
                  end
              else if (groupi = 0) and (values = 'APPID')and inappidtable then
                  begin
                    IgnoredSource := true;
                  end
              else if (groupi = 0) and (values = dxfName_Style)and instyletable then
                  begin
                    IgnoredSource := true;
                  end
              else if (groupi = 0) and (values = dxfName_LType)and inlttypetable then
                  begin
                    IgnoredSource := true;
                  end
              else if (groupi = 0) and (values = dxfName_DIMSTYLE)and indimstyletable then
                  begin
                    IgnoredSource := true;
                  end
                else
                begin
                  if not ignoredsource then
                  begin
                  outstream.TXTAddGDBStringEOL(groups);
                  outstream.TXTAddGDBStringEOL(values);
                  end;
                  //val('$' + values, i, cod);
                end;
    //s := readspace(s);
  end;
  //templatefileclose;

  i:=outstream.Count;
  outstream.Count:=handlepos;
  outstream.TXTAddGDBStringEOL(inttohex(handle+$100000000,9){'100000013'});
  outstream.Count:=i;

  //-------------FileSeek(outstream,handlepos,0);
  //-------------WriteString_EOL(outstream,inttohex(handle+1,8));
  //-------------fileclose(outstream);


  //GDBFreeMem(GDBPointer(phandlea));
  OldHandele2NewHandle.Destroy;
  templatefile.done;

  if FileExists({$IFNDEF DELPHI}utf8tosys{$ENDIF}(name)) then
                           begin
                                if (not(deletefile(name+'.bak')) or (not renamefile(name,name+'.bak'))) then
                                begin
                                   shared.HistoryOutStr(format(rsUnableRenameFileToBak,[name]));
                                end;
                           end;

  if outstream.SaveToFile(name)<=0 then
                                       begin
                                       shared.ShowError(format(rsUnableToWriteFile,[name]));
                                       result:=false;
                                       end
                                   else
                                       result:=true;
  if assigned(EndLongProcessProc)then
  EndLongProcessProc;

  end;
  outstream.done;
  if @SetCurrentDWGProc<>nil
                           then
                               if olddwg<>nil then
                                                  SetCurrentDWGProc(olddwg);
  {$IFNDEF DELPHI}
  Handle2pointer.Destroy;
  VarsDict.destroy;
  {$ENDIF}
  //gdb.SetCurrentDWG(olddwg);
end;
procedure SaveZCP(name: GDBString; {gdb: PGDBDescriptor}var drawing:TSimpleDrawing);
var
//  memsize:longint;
//  objcount:GDBInteger;
//  pmem,tmem:GDBPointer;
  outfile:GDBInteger;
  memorybuf:PGDBOpenArrayOfByte;
  //s:ZCPHeader;
  linkbyf:PGDBOpenArrayOfTObjLinkRecord;
//  test:gdbvertex;
  sub:integer;
begin
     memorybuf:=nil;
     linkbyf:=nil;
     //s:=NULZCPHeader;
     zcpmode:=zcptxt;
     sub:=0;
     sysunit^.TypeName2PTD('ZCPHeader')^.Serialize(@ZCPHead,SA_SAVED_TO_SHD,memorybuf,linkbyf,sub);

     PTZCPOffsetTable(memorybuf^.getelement(ZCPHeadOffsetTableOffset))^.GDB:=memorybuf^.Count;

     linkbyf^.SetGenMode(EnableGen);
     //sysunit.TypeName2PTD('GDBDescriptor')^.Serialize(gdb,SA_SAVED_TO_SHD,memorybuf,linkbyf); убратькомент!!!!

     PTZCPOffsetTable(memorybuf^.getelement(ZCPHeadOffsetTableOffset))^.GDBRT:=memorybuf^.Count;

     linkbyf^.SetGenMode(DisableGen);

     {test.x:=1;
     test.y:=2;
     test.z:=3;
     systype.TypeName2PTD('GDBvertex')^.Serialize(@test,SA_SAVED_TO_SHD,memorybuf,linkbyf);}

     linkbyf^.Minimize;
     //sysunit.TypeName2PTD('GDBOpenArrayOfTObjLinkRecord')^.Serialize(linkbyf,SA_SAVED_TO_SHD,memorybuf,linkbyf);убратькомент!!!!

     {systype.TypeName2PTD('ZCPHeader')^.DeSerialize(@s,SA_SAVED_TO_SHD,memorybuf);
     fillchar(gdb^,sizeof(GDBDescriptor),0);
     systype.TypeName2PTD('GDBDescriptor')^.DeSerialize(gdb,SA_SAVED_TO_SHD,memorybuf);}

     outfile:=FileCreate({$IFNDEF DELPHI}UTF8ToSys{$ENDIF}(name));
     FileWrite(outfile,memorybuf^.parray^,memorybuf^.Count);
     fileclose(outfile);
     outfile:=FileCreate({$IFNDEF DELPHI}UTF8ToSys{$ENDIF}(name+'remap'));
     FileWrite(outfile,linkbyf^.parray^,linkbyf^.Count*linkbyf^.Size);
     fileclose(outfile);
     memorybuf^.done;
     linkbyf^.done;
end;
procedure LoadZCP(name: GDBString; {gdb: PGDBDescriptor}var drawing:TSimpleDrawing);
//var
//  objcount:GDBInteger;
//  pmem,tmem:GDBPointer;
//  infile:GDBInteger;
//  head:ZCPheader;
  //memorybuf:GDBOpenArrayOfByte;
  //FileHeader:ZCPHeader;
//  test:gdbvertex;
  //linkbyf:PGDBOpenArrayOfTObjLinkRecord;
begin
     (*
     FileHeader:=NULZCPHeader;
     memorybuf.InitFromFile(name);
     sysunit.TypeName2PTD('ZCPHeader')^.DeSerialize(@FileHeader,SA_SAVED_TO_SHD,memorybuf,nil);
     HistoryOutStr('Loading file: '+name);
     HistoryOutStr('ZCad project file v'+inttostr(FileHeader.HiVersion)+'.'+inttostr(FileHeader.LoVersion));
     HistoryOutStr('File coment: '+FileHeader.Coment);
     memorybuf.Seek(FileHeader.OffsetTable.GDBRT);
     GDBGetMem({$IFDEF DEBUGBUILD}'{E975EEDE-66A9-4391-8E28-17537B7A2C9C}',{$ENDIF}pointer(linkbyf),sizeof(GDBOpenArrayOfTObjLinkRecord));
     sysunit.TypeName2PTD('GDBOpenArrayOfTObjLinkRecord')^.DeSerialize(linkbyf,SA_SAVED_TO_SHD,memorybuf,nil);
     memorybuf.Seek(FileHeader.OffsetTable.GDB);
     fillchar(gdb^,sizeof(GDBDescriptor),0);
     sysunit.TypeName2PTD('GDBDescriptor')^.DeSerialize(gdb,SA_SAVED_TO_SHD,memorybuf,linkbyf);
     gdb.GetCurrentDWG.SetFileName(name);
     gdb.GetCurrentROOT.correctobjects(nil,-1);
     //fillchar(FileHeader,sizeof(FileHeader),0);
     {systype.TypeName2PTD('GDBVertex')^.DeSerialize(@test,SA_SAVED_TO_SHD,memorybuf);}
     FileRead(infile,header,sizeof(shdblockheader));
     while header.blocktype<>shd_block_eof do
     begin
          case header.blocktype of
                                  shd_block_head:begin
                                                      FileRead(infile,head,sizeof(ZCPheader));
                                                 end;
                              shd_block_primitiv:begin
                                                      FileRead(infile,objcount,sizeof(objcount));
                                                      header.blocksize:=header.blocksize-sizeof(objcount);
                                                      GDBGetMem({$IFDEF DEBUGBUILD}'{01399BB7-5744-4DFE-97C3-00F5E501275C}',{$ENDIF}pmem,header.blocksize);
                                                      FileRead(infile,pmem^,header.blocksize);
                                                      tmem:=pmem;
                                                      //gdb.ObjRoot.ObjArray.LoadCompactMemSize2(tmem,objcount);
                                                      GDBFreeMem(pmem);
                                                 end;
                                            else begin
                                                      FileSeek(infile,header.blocksize,1)
                                                 end;
          end;
          FileRead(infile,header,sizeof(shdblockheader));
     end;
     fileclose(infile);*)
end;
{$IFNDEF DELPHI}
procedure Import(name: GDBString;var drawing:TSimpleDrawing);
var
  Vec: TvVectorialDocument;
  source:{TvVectorialPage}TvPage;
  CurEntity: TvEntity;
  i:integer;
  pobj:PGDBObjEntity;
  j{, k}: Integer;
  CurSegment: TPathSegment;
  Cur2DSegment: T2DSegment absolute CurSegment;
  PosX, PosY: Double;
  DC:TDrawContext;
begin
    Vec := TvVectorialDocument.Create;
     DC:=drawing.CreateDrawingRC;
  try
    Vec.ReadFromFile(name);
    source:=Vec.GetPage(0);
    for i := 0 to source.GetEntitiesCount - 1 do
    begin
      CurEntity := source.GetEntity(i);
      if CurEntity is TvCircle then
      begin
           pobj := CreateInitObjFree(GDBCircleID,nil);
           pgdbobjCircle(pobj)^.Radius:=TvCircle(CurEntity).Radius;
           pgdbobjCircle(pobj)^.Local.P_insert.x:=TvCircle(CurEntity).x;
           pgdbobjCircle(pobj)^.Local.P_insert.y:=TvCircle(CurEntity).y;
           drawing{gdb}.GetCurrentRoot^.AddMi(@pobj);
           PGDBObjEntity(pobj)^.BuildGeometry(drawing);
           PGDBObjEntity(pobj)^.formatEntity(drawing,dc);
      end
 else if CurEntity is TvCircularArc then
      begin
           pobj := CreateInitObjFree(GDBArcID,nil);
           pgdbobjArc(pobj)^.R:=TvCircularArc(CurEntity).Radius;
           pgdbobjArc(pobj)^.Local.P_insert.x:=TvCircularArc(CurEntity).x;
           pgdbobjArc(pobj)^.Local.P_insert.y:=TvCircularArc(CurEntity).y;
           pgdbobjArc(pobj)^.StartAngle:=TvCircularArc(CurEntity).StartAngle*pi/180;
           pgdbobjArc(pobj)^.EndAngle:=TvCircularArc(CurEntity).EndAngle*pi/180;
           drawing{gdb}.GetCurrentRoot^.AddMi(@pobj);
           PGDBObjEntity(pobj)^.BuildGeometry(drawing);
           PGDBObjEntity(pobj)^.formatEntity(drawing,dc);
      end
  else if CurEntity is fpvectorial.TPath then
      begin
      fpvectorial.TPath(CurEntity).PrepareForSequentialReading;
      for j := 0 to fpvectorial.TPath(CurEntity).Len - 1 do
      begin
        CurSegment := TPathSegment(fpvectorial.TPath(CurEntity).Next());

        case CurSegment.SegmentType of
        stMoveTo:
        begin
          PosX := Cur2DSegment.X;
          PosY := Cur2DSegment.Y;
        end;
        st2DLineWithPen,st2DLine, st3DLine:
        begin
           pobj := CreateInitObjFree(GDBLineID,nil);
           PGDBObjLine(pobj)^.CoordInOCS.lBegin:=createvertex(PosX,PosY,0);
           PosX := Cur2DSegment.X;
           PosY := Cur2DSegment.Y;
           PGDBObjLine(pobj)^.CoordInOCS.lEnd:=createvertex(PosX,PosY,0);
           drawing{gdb}.GetCurrentRoot^.AddMi(@pobj);
           PGDBObjEntity(pobj)^.BuildGeometry(drawing);
           PGDBObjEntity(pobj)^.formatEntity(drawing,dc);
        end;
        end;
      end;

      end;
    end;
  except
        on Exception do
        begin
             shared.ShowError('Unsupported vector graphics format?');
        end
  end;
  //finally
    Vec.Free;
  //end;
end;
{$ENDIF}
begin
     {$IFDEF DEBUGINITSECTION}log.LogOut('iodxf.initialization');{$ENDIF} 
     i2:=0;
     FOC:=0;
     Ext2LoadProcMap.RegisterExt('dxf','AutoCAD DXF files (*.dxf)',@addfromdxf,true);
end.
