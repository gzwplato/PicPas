{
XpresElements 0.7b
=============
Definiciones para el manejo de los elementos del compilador: funciones, constantes, variables.
Todos estos elementos se almacenan en una estrucutura de arbol.
Por Tito Hinostroza.
 }
unit XpresElements;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, fgl, XpresTypes;

type
  //Tipos de elementos del lenguaje
  TxpElemType = (et_None,   //sin tipo
                 et_Main,   //programa principal
                 et_Var,    //variable
                 et_Func,   //función
                 et_Cons    //constante
                );
  TFindFuncResult = (TFF_NONE, TFF_PARTIAL, TFF_FULL);

  TxpElement = class;
  TxpElements = specialize TFPGObjectList<TxpElement>;

  { TxpElement }
  //Clase base para todos los elementos
  TxpElement = class
  public
  private
    amb  : string;   //ámbito o alcance de la constante
  public
    name : string;   //nombre de la variable
    typ  : Ttype;    //tipo de la variable
    Parent: TxpElement;  //referecnia al padre
    elemType: TxpElemType;  //no debería ser necesario
    Used: integer;  //veces que se usa este nombre
    elements: TxpElements;  //referencia a nombres anidados, cuando sea función
    function AddElement(elem: TxpElement): TxpElement;
    function DuplicateIn(list: TObject): boolean; virtual;
    function FindIdxElemName(const eName: string; var idx0: integer): boolean;
    constructor Create; virtual;
    destructor Destroy; override;
  end;

  TVarOffs = word;
  TVarBank = byte;

  //Clase para modelar al bloque principal
  { TxpMain }
  TxpMain = class(TxpElement)
    constructor Create; override;
  end;

  //Clase para modelar a las constantes
  { TxpCon }
  TxpCon = class(TxpElement)
    //valores de la constante
    val : TConsValue;
    constructor Create; override;
  end;
//  TxpCons = specialize TFPGObjectList<TxpCon>; //lista de variables

  //Clase para modelar a las variables
  { TxpVar }
  TxpVar = class(TxpElement)
    //direción física. Usado para implementar un compilador
    offs: TVarOffs;
    bank: TVarBank;  //banco o segmento. Usado solo en algunas arquitecturas
    bit : byte;      //posición del bit. Usado para variables booleanas.
    constructor Create; override;
  end;
  TxpVars2 = specialize TFPGObjectList<TxpVar>; //lista de variables

  //Clase para almacenar información de las funciones
  { TxpFun }
  TxpFun = class;
  TProcExecFunction = procedure(fun :TxpFun);  //con índice de función
  TxpFun = class(TxpElement)
  private

  public
    pars: array of Ttype;  //parámetros de entrada
    //direción física. Usado para implementar un compilador
    adrr: integer;  //dirección física
    //Campos usados para implementar el intérprete sin máquina virtual
    proc: TProcExecFunction;  //referencia a la función que implementa
    posF: TPoint;    //posición donde empieza la función en el código fuente
    procedure ClearParams;
    procedure CreateParam(parName: string; typ0: ttype);
    function SameParams(Fun2: TxpFun): boolean;
    function ParamTypesList: string;
    function DuplicateIn(list: TObject): boolean; override;
    constructor Create; override;
  end;
//  TxpFuns = specialize TFPGObjectList<TxpFun>;

  { TXpTreeElements }
  {Arbol de elementos. Solo se espera que haya una instacia de este objeto. Aquí es
  donde se guardará la referencia a todas los elementos (variables, constantes, ..)
  creados.
  Este arcbol se usa también como un equivalente al NameSpace, proque se usa para
  buscar los nombres de los elementos, en una estructura en arbol}
  TXpTreeElements = class
  private
    curNode : TxpElement;  //referencia al nodo actual
    vars    : TxpVars2;
    //variables de estado para la búsqueda con FindFirst() - FindNext()
    curFindName: string;
    curFindNode: TxpElement;
    curFindIdx: integer;
  public
    main    : TxpMain;  //nodo raiz
    procedure Clear;
    function AllVars: TxpVars2;
    function CurNodeName: string;
    //funciones para llenado del arbol
    function AddElement(elem: TxpElement; verifDuplic: boolean=true): boolean;
    procedure OpenElement(elem: TxpElement);
    function ValidateCurElement: boolean;
    procedure CloseElement;
    //Métodos para identificación de nombres
    function FindFirst(const name: string): TxpElement;
    function FindNext: TxpElement;
    function FindFuncWithParams(const funName: string; const func0: TxpFun;
      var fmatch: TxpFun): TFindFuncResult;
    function FindVar(varName: string): TxpVar;
  public  //constructor y destructror
    constructor Create; virtual;
    destructor Destroy; override;
  end;

implementation

{ TxpElement }
function TxpElement.AddElement(elem: TxpElement): TxpElement;
{Agrega un elemento hijo al elemento actual. Devuelve referencia. }
begin
  elem.Parent := self;  //actualzia referencia
  elements.Add(elem);   //agrega a la lista de nombres
  Result := elem;       //no tiene mucho sentido
end;
function TxpElement.DuplicateIn(list: TObject): boolean;
{Debe indicar si el elemento está duplicado en la lista de elementos proporcionada.}
var
  uName: String;
  ele: TxpElement;
begin
  uName := upcase(name);
  for ele in TxpElements(list) do begin
    if upcase(ele.name) = uName then begin
      exit(true);
    end;
  end;
  exit(false);
end;
function TxpElement.FindIdxElemName(const eName: string; var idx0: integer): boolean;
{Busca un nombre en su lista de elementos. Inicia buscando en idx0, hasta el final.
 Si encuentra, devuelve TRUE y deja en idx0, la posición en donde se encuentra.}
var
  i: Integer;
  uName: String;
begin
  uName := upcase(eName);
  //empieza la búsqueda en "idx0"
  for i := idx0 to elements.Count-1 do begin
    { TODO : Tal vez sería mejor usar el método de búsqueda interno de la lista,
     que es más rápido, pero trabaja con listas ordenadas. }
    if upCase(elements[i].name) = uName then begin
      //sale dejando idx0 en la posición encontrada
      idx0 := i;
      exit(true);
    end;
  end;
  exit(false);
end;
constructor TxpElement.Create;
begin
  elemType := et_None;
end;
destructor TxpElement.Destroy;
begin
  elements.Free;  //por si contenía una lista
  inherited Destroy;
end;

{ TxpMain }
constructor TxpMain.Create;
begin
  elemType:=et_Main;
  Parent := nil;  //la raiz no tiene padre
end;

{ TxpCon }
constructor TxpCon.Create;
begin
  elemType:=et_Cons;
end;

{ TxpVar }
constructor TxpVar.Create;
begin
  elemType:=et_Var;
end;

{ TxpFun }
procedure TxpFun.ClearParams;
//Elimina los parámetros de una función
begin
  setlength(pars,0);
end;
procedure TxpFun.CreateParam(parName: string; typ0: ttype);
//Crea un parámetro para la función
var
  n: Integer;
begin
  //agrega
  n := high(pars)+1;
  setlength(pars, n+1);
  pars[n] := typ0;  //agrega referencia
end;
function TxpFun.SameParams(Fun2: TxpFun): boolean;
{Compara los parámetros de la función con las de otra. Si tienen el mismo número
de parámetros y el mismo tipo, devuelve TRUE.}
var
  i: Integer;
begin
  Result:=true;  //se asume que son iguales
  if High(pars) <> High(Fun2.pars) then
    exit(false);   //distinto número de parámetros
  //hay igual número de parámetros, verifica
  for i := 0 to High(pars) do begin
    if pars[i] <> Fun2.pars[i] then begin
      exit(false);
    end;
  end;
  //si llegó hasta aquí, hay coincidencia, sale con TRUE
end;
function TxpFun.ParamTypesList: string;
{Devuelve una lista con los nombres de los tipos de los parámetros, de la forma:
(byte, word) }
var
  tmp: String;
  j: Integer;
begin
  tmp := '';
  for j := 0 to High(pars) do begin
    tmp += pars[j].name+', ';
  end;
  //quita coma final
  if length(tmp)>0 then tmp := copy(tmp,1,length(tmp)-2);
  Result := '('+tmp+')';
end;
function TxpFun.DuplicateIn(list: TObject): boolean;
var
  uName: String;
  ele: TxpElement;
begin
  uName := upcase(name);
  for ele in TxpElements(list) do begin
    if ele = self then Continue;  //no se compara el mismo
    if upcase(ele.name) = uName then begin
      //hay coincidencia de nombre
      if ele.elemType = et_Func then begin
        //para las funciones, se debe comparar los parámetros
        if SameParams(TxpFun(ele)) then begin
          exit(true);
        end;
      end else begin
        //si tiene el mismo nombre que cualquier otro elemento, es conflicto
        exit(true);
      end;
    end;
  end;
  exit(false);
end;
constructor TxpFun.Create;
begin
  elemType:=et_Func;
end;

{ TXpTreeElements }
procedure TXpTreeElements.Clear;
begin
  main.elements.Clear;  //esto debe hacer un borrado recursivo
  curNode := main;      //retorna al nodo principal
end;
function TXpTreeElements.AllVars: TxpVars2;
{Devuelve una lista de todas las variables usadas, incluyendo las de las funciones y
 procedimientos.}
  procedure AddVars(nod: TxpElement);
  var
    ele : TxpElement;
  begin
    if nod.elements<>nil then begin
      for ele in nod.elements do begin
        if ele.elemType = et_Var then begin
          vars.Add(TxpVar(ele));
        end else begin
          if ele.elements<>nil then
            AddVars(ele);  //recursivo
        end;
      end;
    end;
  end;
var
  ele : TxpElement;
begin
  if vars = nil then begin  //debe estar creada la lista
    vars := TxpVars2.Create(false);
  end else begin
    vars.Clear;   //por si estaba llena
  end;
  AddVars(curNode);
  Result := vars;
end;
function TXpTreeElements.CurNodeName: string;
{Devuelve el nombre del nodo actual}
begin
  Result := curNode.name;
end;

//funciones para llenado del arbol
function TXpTreeElements.AddElement(elem: TxpElement; verifDuplic: boolean = true): boolean;
{Agrega un elemento al nodo actual. Si ya existe el nombre del nodo, devuelve false}
begin
  Result := true;
  //Verifica si hay conflicto. Solo es necesario buscar en el nodo actual.
  if verifDuplic and elem.DuplicateIn(curNode.elements) then begin
    exit(false);  //ya existe
  end;
  //agrega el nodo
  curNode.AddElement(elem);
end;
procedure TXpTreeElements.OpenElement(elem: TxpElement);
{Agrega un elemento y cambia el nodo actual. Este método está reservado para
las funciones o procedimientos}
begin
  {las funciones o procedimientos no se validan inicialmente, sino hasta que
  tengan todos sus parámetros agregados, porque pueden ser sobrecargados.}
  curNode.AddElement(elem);
  //Genera otro espacio de nombres
  elem.elements := TxpElements.Create(true);  //su propia lista
  curNode := elem;  //empieza a trabajar en esta lista
end;
function TXpTreeElements.ValidateCurElement: boolean;
{Este método es el complemento de OpenElement(). Se debe llamar cuando ya se
 tienen creados los parámetros de la función o procedimiento, para verificar
 si hay duplicidad, en cuyo caso devolverá FALSE}
begin
  //Se asume que el nodo a validar ya se ha abierto, con OpenElement() y es el actual
  if curNode.DuplicateIn(curNode.Parent.elements) then begin  //busca en el nodo anterior
    exit(false);
  end else begin
    exit(true);
  end;
end;
procedure TXpTreeElements.CloseElement;
{Sale del nodo actual y retorna al nodo padre}
begin
  if curNode.Parent<>nil then
    curNode := curNode.Parent;
end;
//Métodos para identificación de nombres
function TXpTreeElements.FindFirst(const name: string): TxpElement;
{Busca un nombre siguiendo la estructura del espacio de nombres (primero en el espacio
 actual y luego en los espacios padres).
 Si encuentra devuelve la referencia. Si no encuentra, devuelve NIL}
  function FindFirstIn(nod: TxpElement): TxpElement;
  var
    idx0: integer;
  begin
    curFindNode := nod;  //Busca primero en el espacio actual
    {Busca con FindIdxElemName() para poder saber donde se deja la exploración y poder
     retomarla luego con FindNext().}
    idx0 := 0;  //la primera búsqueda se hace desde el inicio
    if curFindNode.FindIdxElemName(name, idx0) then begin
      //Lo encontró, deja estado listo para la siguiente búsqueda
      curFindIdx:= idx0+1;
      Result := curFindNode.elements[idx0];
      exit;
    end else begin
      //No encontró
      if nod.Parent = nil then begin
        Result := nil;
        exit;  //no hay espacios padres
      end;
      //busca en el espacio padre
      Result := FindFirstIn(nod.Parent);  //recursividad
      exit;
    end;
  end;
begin
  curFindName := name;     //actualiza para FindNext()
  Result := FindFirstIn(curNode);
end;
function TXpTreeElements.FindNext: TxpElement;
{Continúa la búsqueda iniciada con FindFirst().}
begin

end;
function TXpTreeElements.FindFuncWithParams(const funName: string; const func0: TxpFun;
  var fmatch: TxpFun): TFindFuncResult;
{Busca una función que coincida con el nombre "funName" y con los parámetros de func0
El resultado puede ser:
 TFF_NONE   -> No se encuentra.
 TFF_PARTIAL-> Se encuentra solo el nombre.
 TFF_FULL   -> Se encuentra y coninciden sus parámetros, actualiza "fmatch".
}
var
  tmp: String;
  params : string;   //parámetros de la función
  ele: TxpElement;
  hayFunc: Boolean;
begin
  Result := TFF_NONE;   //por defecto
  hayFunc := false;
  tmp := UpCase(funName);
  for ele in curNode.elements do begin
    if (ele.elemType = et_Func) and (Upcase(ele.name) = tmp) then begin
      //coincidencia de nombre, compara parámetros
      hayFunc := true;  //para indicar que encontró el nombre
      if func0.SameParams(TxpFun(ele)) then begin
        fmatch := TxpFun(ele);  //devuelve ubicación
        Result := TFF_FULL;     //encontró
        exit;
      end;
    end;
  end;
  //si llego hasta aquí es porque no encontró coincidencia
  if hayFunc then begin
    //Encontró al menos el nombre de la función, pero no coincide en los parámetros
    Result := TFF_PARTIAL;
    {Construye la lista de parámetros de las funciones con el mismo nombre. Solo
    hacemos esta tarea pesada aquí, porque  sabemos que se detendrá la compilación}
    params := '';   //aquí almacenará la lista
{    for i:=idx0 to high(funcs) do begin  //no debe empezar 1n 0, porque allí está func[0]
      if Upcase(funcs[i].name)= tmp then begin
        for j:=0 to high(funcs[i].pars) do begin
          params += funcs[i].pars[j].name + ',';
        end;
        params += LineEnding;
      end;
    end;}
  end;
end;
function TXpTreeElements.FindVar(varName: string): TxpVar;
{Busca una variable con el nombre indicado en el espacio de nombres actual}
var
  ele : TxpElement;
  uName: String;
begin
  uName := upcase(varName);
  for ele in curNode.elements do begin
    if (ele.elemType = et_Var) and (upCase(ele.name) = uName) then begin
      Result := TxpVar(ele);
      exit;
    end;
  end;
  exit(nil);
end;
//constructor y destructror
constructor TXpTreeElements.Create;
begin
  main:= TxpMain.Create;  //No debería
  main.elements := TxpElements.Create(true);  //debe tener lista
  curNode := main;  //empieza con el nodo principal como espacio de nombres actual
end;
destructor TXpTreeElements.Destroy;
begin
  main.Destroy;
  vars.Free;    //por si estaba creada
  inherited Destroy;
end;
end.

