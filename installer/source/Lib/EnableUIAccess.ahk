EnableUIAccess(filename)
{
    hStore := DllCall("Crypt32\CertOpenStore", "ptr", 10 ; STORE_PROV_SYSTEM_W
        , "uint", 0, "ptr", 0, "uint", 0x20000 ; SYSTEM_STORE_LOCAL_MACHINE
        , "wstr", "Root", "ptr")
    if !hStore
        throw "CertOpenStore"
    ; Find or create certificate for signing.
    p := DllCall("Crypt32\CertFindCertificateInStore", "ptr", hStore
        , "uint", 0x10001 ; X509_ASN_ENCODING|PKCS_7_ASN_ENCODING
        , "uint", 0, "uint", 0x80007 ; FIND_SUBJECT_STR
        , "wstr", "AutoHotkey", "ptr", 0, "ptr")
    if p
        cert := new CertContext(p)
    else
        cert := EnableUIAccess_CreateCert("AutoHotkey", hStore)
    ; Set uiAccess attribute in manifest.
    EnableUIAccess_SetManifest(filename)
    ; Sign the file (otherwise uiAccess attribute is ignored).
    EnableUIAccess_SignFile(filename, cert, "AutoHotkey")
}

EnableUIAccess_SetManifest(file)
{
    xml := ComObjCreate("Msxml2.DOMDocument")
    xml.async := false
    xml.setProperty("SelectionLanguage", "XPath")
    xml.setProperty("SelectionNamespaces"
        , "xmlns:v1='urn:schemas-microsoft-com:asm.v1' "
        . "xmlns:v3='urn:schemas-microsoft-com:asm.v3'")
    if !xml.load("res://" file "/#24/#1") ; Load current manifest
        throw "manifest/load"
    
    node := xml.selectSingleNode("/v1:assembly/v3:trustInfo/v3:security"
                    . "/v3:requestedPrivileges/v3:requestedExecutionLevel")
    if !node ; Not AutoHotkey v1.1?
        throw "manifest/parse"
    
    node.setAttribute("uiAccess", "true")
    xml := RTrim(xml.xml, "`r`n")
    
    VarSetCapacity(data, data_size := StrPut(xml, "utf-8") - 1)
    StrPut(xml, &data, "utf-8")
    
    if !(hupd := DllCall("BeginUpdateResource", "str", file, "int", false))
        throw "rsrc"
    r := DllCall("UpdateResource", "ptr", hupd, "ptr", 24, "ptr", 1
                    , "ushort", 1033, "ptr", &data, "uint", data_size)
    if !DllCall("EndUpdateResource", "ptr", hupd, "int", !r) && r
        throw "rsrc"
}

EnableUIAccess_CreateCert(CertName, hStore)
{
    if !DllCall("Advapi32\CryptAcquireContext", "ptr*", hProv
        , "str", CertName, "ptr", 0, "uint", 1, "uint", 0) ; PROV_RSA_FULL=1, open existing=0
    {
        if !DllCall("Advapi32\CryptAcquireContext", "ptr*", hProv
            , "str", CertName, "ptr", 0, "uint", 1, "uint", 8) ; PROV_RSA_FULL=1, CRYPT_NEWKEYSET=8
            throw "CryptAcquireContext"
        prov := new CryptContext(hProv)

        if !DllCall("Advapi32\CryptGenKey", "ptr", hProv
                , "uint", 2, "uint", 0x4000001, "ptr*", hKey) ; AT_SIGNATURE=2, EXPORTABLE=..01
            throw "CryptGenKey"
        (new CryptKey(hKey)) ; To immediately release it.
    }

    Loop 2
    {
        if A_Index = 1
            pbName := cbName := 0
        else
            VarSetCapacity(bName, cbName), pbName := &bName
        if !DllCall("Crypt32\CertStrToName", "uint", 1, "str", "CN=" CertName
            , "uint", 3, "ptr", 0, "ptr", pbName, "uint*", cbName, "ptr", 0) ; X509_ASN_ENCODING=1, CERT_X500_NAME_STR=3
            throw "CertStrToName"
    }
    VarSetCapacity(cnb, 2*A_PtrSize), NumPut(pbName, NumPut(cbName, cnb))

    VarSetCapacity(endTime, 16)
    DllCall("GetSystemTime", "ptr", &endTime)
    NumPut(NumGet(endTime, "ushort") + 10, endTime, "ushort") ; += 10 years

    if !hCert := DllCall("Crypt32\CertCreateSelfSignCertificate"
        , "ptr", hProv, "ptr", &cnb, "uint", 0, "ptr", 0
        , "ptr", 0, "ptr", 0, "ptr", &endTime, "ptr", 0, "ptr")
        throw "CertCreateSelfSignCertificate"
    cert := new CertContext(hCert)

    if !DllCall("Crypt32\CertAddCertificateContextToStore", "ptr", hStore
        , "ptr", hCert, "uint", 1, "ptr", 0) ; STORE_ADD_NEW=1
        throw "CertAddCertificateContextToStore"

    return cert
}

EnableUIAccess_DeleteCertAndKey(CertName)
{
    DllCall("Advapi32\CryptAcquireContext", "ptr*", undefined
        , "str", CertName, "ptr", 0, "uint", 1, "uint", 16) ; PROV_RSA_FULL=1, CRYPT_DELETEKEYSET=16
    if !hStore := DllCall("Crypt32\CertOpenStore", "ptr", 10 ; STORE_PROV_SYSTEM_W
        , "uint", 0, "ptr", 0, "uint", 0x20000 ; SYSTEM_STORE_LOCAL_MACHINE
        , "wstr", "Root", "ptr")
		throw "CertOpenStore"
	if !p := DllCall("Crypt32\CertFindCertificateInStore", "ptr", hStore
        , "uint", 0x10001 ; X509_ASN_ENCODING|PKCS_7_ASN_ENCODING
        , "uint", 0, "uint", 0x80007 ; FIND_SUBJECT_STR
        , "wstr", CertName, "ptr", 0, "ptr")
		return 0
	if !DllCall("Crypt32\CertDeleteCertificateFromStore", "ptr", p)
		throw "CertDeleteCertificateFromStore"
	return 1
}

class CryptContext {
    __New(p) {
        this.p := p
    }
    __Delete() {
        DllCall("Advapi32\CryptReleaseContext", "ptr", this.p, "uint", 0)
    }
}
class CertContext extends CryptContext {
    __Delete() {
        DllCall("Crypt32\CertFreeCertificateContext", "ptr", this.p)
    }
}
class CryptKey extends CryptContext {
    __Delete() {
        DllCall("Advapi32\CryptDestroyKey", "ptr", this.p)
    }
}

EnableUIAccess_SignFile(File, CertCtx, Name)
{
    VarSetCapacity(wfile, 2 * StrPut(File, "utf-16")), StrPut(File, &wfile, "utf-16")
    VarSetCapacity(wname, 2 * StrPut(Name, "utf-16")), StrPut(Name, &wname, "utf-16")
    cert_ptr := IsObject(CertCtx) ? CertCtx.p : CertCtx

    EnableUIAccess_Struct(file_info, "ptr", A_PtrSize*3 ; SIGNER_FILE_INFO
        , "ptr", &wfile)
    VarSetCapacity(dwIndex, 4, 0) ; DWORD
    EnableUIAccess_Struct(subject_info, "ptr", A_PtrSize*4 ; SIGNER_SUBJECT_INFO
        , "ptr", &dwIndex, "ptr", SIGNER_SUBJECT_FILE:=1, "ptr", &file_info)
    EnableUIAccess_Struct(cert_store_info, "ptr", A_PtrSize*4 ; SIGNER_CERT_STORE_INFO
        , "ptr", cert_ptr, "ptr", SIGNER_CERT_POLICY_CHAIN:=2)
    EnableUIAccess_Struct(cert_info, "uint", 8+A_PtrSize*2 ; SIGNER_CERT
        , "uint", SIGNER_CERT_STORE:=2, "ptr", &cert_store_info)
    EnableUIAccess_Struct(authcode_attr, "uint", 8+A_PtrSize*3 ; SIGNER_ATTR_AUTHCODE
        , "int", false, "ptr", true, "ptr", &wname)
    EnableUIAccess_Struct(sig_info, "uint", 8+A_PtrSize*4 ; SIGNER_SIGNATURE_INFO
        , "uint", CALG_SHA1:=0x8004, "ptr", SIGNER_AUTHCODE_ATTR:=1
        , "ptr", &authcode_attr)

    hr := DllCall("MSSign32\SignerSign"
        , "ptr", &subject_info, "ptr", &cert_info, "ptr", &sig_info
        , "ptr", 0, "ptr", 0, "ptr", 0, "ptr", 0, "uint")
    if (hr != 0)
        throw hr
}

EnableUIAccess_Struct(ByRef struct, arg*)
{
    VarSetCapacity(struct, arg[2], 0), p := &struct
    Loop % arg.Length()//2
        p := NumPut(arg[2], p+0, arg[1]), arg.RemoveAt(1, 2)
    return &struct
}