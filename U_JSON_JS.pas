unit U_JSON_JS;


 {** Unit desenvolvida por Jonatan Souza

   Ela é converter JSON para FireDac e FireDac para JSON, cria um arquivo simples JSON e faz o encode.
   Você pode alterar o método de criptografia de sua vontade nas funções _Encode64 e _Decode64


   *-------------------------------------------------------*
   | Data : 20/01/2016                                     |
   | E-mail : jonatan.souza04@gmail.com                    |
   *--------------------------------------------------------*

   O funcionamento é simples, basta declarar esta Unit no seu projeto e chamar as funções :

   Converter para JSON

   LimparCampos( Sua Query FirecDac )
   ShowMessage(  FDToJSON('Clientes', Sua Query FirecDac ) );


   Converter para FireDac

   LimparCampos( Sua Query FirecDac )
   Sua Query FirecDac := JSONToFD( String JSON ).



   Obs : o componente FireDac não pode ter fields fixo, tem que ser uma query "limpa".

   Espero que ajude.

  }


interface

Uses System.SysUtils, System.StrUtils, System.Classes, System.Json,System.IOUtils,
     FireDAC.Comp.Client, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
     FireDAC.Stan.Async, FireDAC.Phys, Data.DB,
     System.Hash, IdCoderMIME, IdGlobal, FMX.Dialogs, ZLib;




  {** Funcões principais}

  Function FDToJSON( Ident { Identificação Qualquer, exemplo "Cliente"} : String; QrFD: TFDQuery): String;
  Function JSONToFD( Ident,{ Identificação Qualquer, exemplo "Cliente"}  sJSON : String; var FDMe : TFDMemTable ) : Boolean ;

  {**}

  Function BoolStrT( bValor : Boolean ) : String;
  Procedure LimparCampos( FDMe : TFDMemTable );

  Function _Encode64(const S: String ): String;
  Function _Decode64(const S: String ): String;
  Function _EInteiro( iValor : String ) : Boolean;
  Function _EFloat( fValor : String ) : Boolean;
  Function _EData( dValor : String ) : Boolean;
  Function _EHora( hValor : String ) : Boolean;

  Function _ZCompressString(aText: String ): String;
  Function _ZDecompressString(aText: String ): String;

implementation


Function FDToJSON( Ident : String; QrFD: TFDQuery): String;
Var
 i : Integer;
 TFileJSON : String;
begin

  Result := '';

  if QrFD.RecordCount > 0 then
  Begin

     TFileJSON := ' {"' + TFileJSON + Ident + '":[';

     QrFD.First;

     while Not QrFD.Eof do
     Begin

        TFileJSON :=  TFileJSON + ('{');

        for i := 0 to QrFD.Fields.Count - 1 do
        begin

             if QrFD.Fields[i].DataType In [ftInteger, ftAutoInc ] then
              TFileJSON :=  TFileJSON + ('"' + Trim( QrFD.Fields[i].FieldName ) + '":' + Trim( IntToStr( QrFD.Fields[i].AsInteger ) ) )
             Else
             if QrFD.Fields[i].DataType In [ftFloat, ftCurrency ] then
              TFileJSON :=  TFileJSON + ('"' + Trim( QrFD.Fields[i].FieldName ) + '":' + Trim ( FormatFloat('00000.00', QrFD.Fields[i].AsFloat ) ) )
             Else
             if QrFD.Fields[i].DataType In [ftBoolean, ftByte ] then
              TFileJSON :=  TFileJSON + ('"' + Trim( QrFD.Fields[i].FieldName ) + '":' + Trim( LowerCase( BoolStrT ( QrFD.Fields[i].AsBoolean ) ) ) )
             Else
              TFileJSON :=  TFileJSON + ('"' + Trim( QrFD.Fields[i].FieldName ) + '":"' + Trim( QrFD.Fields[i].AsString ) + '"');


             if i < QrFD.Fields.Count - 1 then
             TFileJSON :=  TFileJSON + ',';

        end;

        QrFD.Next;


        if Not QrFD.Eof then
         TFileJSON :=  TFileJSON + '},'
        ELse
         TFileJSON :=  TFileJSON +'}';

     End;

     TFileJSON :=  TFileJSON + ']} ';


     Result := _ZCompressString( TFileJSON );

  End;

End;


Function JSONToFD( Ident, sJSON : String; var FDMe : TFDMemTable ) : Boolean ;
Var

 JSONRet : String;
 LJSONObject: TJSONObject;
 ResultJSONArray : TJSONArray;

 LItem, JV :TJsonValue;
 i : Integer;

Begin

   LJSONObject := Nil;

   JSONRet     := _ZDecompressString( sJSON );

   Try
     LJSONObject := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(JSONRet), 0) as TJSONObject;
   Except On E : Exception Do

    ShowMessage('Erro ao serializar o JSON ' + E.Message + #13 + JSONRet);
   End;


   i := 0;
  // LJSONObject.Get(0);

   ResultJSONArray := (LJSONObject.GetValue( Ident ) as TJSONArray);

   If ResultJSONArray = Nil Then
   Begin

     Result := False;
     Exit;

   End;


     JV := TJSONArray(ResultJSONArray.Get(i));

     FDMe.Close;

     for LItem in TJSONArray( JV ) do
     begin

        if TJSONPair(LItem).JsonValue IS TJSONBool then
         FDMe.FieldDefs.Add(TJSONPair(LItem).JsonString.Value, ftBoolean)
        Else
        if (_EData(TJSONPair(LItem).JsonValue.Value)) then
         FDMe.FieldDefs.Add(TJSONPair(LItem).JsonString.Value, ftDateTime)
        Else
        if (_EHora(TJSONPair(LItem).JsonValue.Value)) then
         FDMe.FieldDefs.Add(TJSONPair(LItem).JsonString.Value, ftTime)
        Else
        if (TJSONPair(LItem).JsonValue IS TJSONNumber) And (_EInteiro(TJSONPair(LItem).JsonValue.Value)) then
         FDMe.FieldDefs.Add(TJSONPair(LItem).JsonString.Value, ftInteger)
        Else
        if (TJSONPair(LItem).JsonValue IS TJSONNumber) And (_EFloat(TJSONPair(LItem).JsonValue.Value)) then
         FDMe.FieldDefs.Add(TJSONPair(LItem).JsonString.Value, ftFloat)
        Else
         FDMe.FieldDefs.Add(TJSONPair(LItem).JsonString.Value, ftString,9999);

     End;

  FDMe.Active := True;

  for i := 0 to ResultJSONArray.Size - 1 do
  Begin

     JV := TJSONArray(ResultJSONArray.Get(i));

     FDMe.Insert;

     for LItem in TJSONArray( JV ) do
     begin

        if TJSONPair( LItem ).JsonString.Value <> '' then
        FDMe.FieldByName( TJSONPair(LItem).JsonString.Value ).Value :=  TJSONPair(LItem).JsonValue.Value;

      end;

     FDMe.Post;

  End;


End;


Function _Encode64(const S: String ): String;
Begin

   if (S <> '') then
    Result :=  TIdEncoderMIME.EncodeString( System.StrUtils.ReverseString(S), IndyTextEncoding_UTF8)
   Else
    Result := '';


End;

Function _Decode64(const S: String ): String;
Begin

   if (S <> '') then
    Result := ReverseString( TIdDecoderMIME.DecodeString(S, IndyTextEncoding_UTF8) )
   Else
    Result := '';

End;

Function BoolStrT( bValor : Boolean ) : String;
Begin

  if bValor then
   Result := 'true'
  Else
   Result := 'false' ;

End;

Procedure LimparCampos( FDMe : TFDMemTable );
Begin

     FDMe.FieldDefs.Clear;

End;


Function _EInteiro( iValor : String ) : Boolean;
Begin

  Result := ( StrToIntDef( iValor,-1) >= 0 );

End;

Function _EFloat( fValor : String ) : Boolean;
Begin

  Result := ( StrToFloatDef( fValor,-1) >= 0 );

End;


Function _EData( dValor : String ) : Boolean;
Begin

  Result := False;

  If ( ( POS('/', dValor ) > 0 ) Or ( POS('-', dValor ) > 0 ) )
  And ( Length(dValor) >= 8 ) And ( StrToDateTimeDef(dValor,-1) > 0 ) then
  Result := True;

End;

Function _EHora( hValor : String ) : Boolean;
Begin

  Result := False;

  if ( POS(':', hValor ) > 0 )
  And ( Length(hValor) >= 5) And (StrToTimeDef(hValor,-1) > 0) then
  Result := True;

End;


function _ZCompressString(aText: String ): String;
Var

  strInput,
  strOutput: TStringStream;
  Zipper: TZCompressionStream;

Begin

  Result:= '';
  Result := _Encode64( aText );

  {
   ** Está função não funciona no IOS 8.3 maior

   strInput  := TStringStream.Create(aText);
  strOutput := TStringStream.Create;

  Try

    Zipper:= TZCompressionStream.Create(clMax,strOutput);
    Try
      Zipper.CopyFrom(strInput, strInput.Size);
    Finally
      Zipper.Free;
    End;

    Result := _Encode64( strOutput.DataString );

  Finally
    strInput.Free;
    strOutput.Free;
  End;
   }
End;

Function _ZDecompressString(aText: string): string;
Var

  strInput,
  strOutput: TStringStream;
  Unzipper: TZDecompressionStream;

Begin

  Result:= '';
  Result := _Decode64( aText );

  {


  ** Está função não funciona no IOS 8.3 maior

  strInput  := TStringStream.Create( _Decode64(aText) );
  strOutput := TStringStream.Create;

  Try

    Unzipper:= TZDecompressionStream.Create(strInput);
    Try
      strOutput.CopyFrom(Unzipper, Unzipper.Size);
    Finally
      Unzipper.Free;
    End;

    Result:=  ( strOutput.DataString );

  Finally
    strInput.Free;
    strOutput.Free;
  End;
   }
end;


end.
