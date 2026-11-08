"""Two real own uploads/versions, normal worker and isolated retained history."""
from p0_crud_global_hml import q,uid
from remaining_domains.document_fixture import competence,wait_document

def run(r):
    f=r.fixture;c=competence(r)
    file=r.upload('competence-v1')
    payload={'p_id_competencia':c,'p_tipo':'outro','p_titulo':f['prefix']+'Competence document','p_categoria':'own','p_id_requisito':None,'p_id_arquivo':file,'p_chave_idempotencia':uid()}
    r.deny('criar_documento_competencia_v115',payload)
    first=r.operation('criar_documento_competencia_v115',payload);doc=r.entity('document',first['id_documento']);v1=r.entity('version1',first['id_versao'])
    r.check('COMP_DOC_CREATE_REPLAY',r.operation('criar_documento_competencia_v115',payload)==first)
    wait_document(r,first,file,'competencia')
    second_file=r.upload('competence-v2')
    edit={'p_id_documento':doc,'p_id_arquivo':second_file,'p_motivo':'Own correction preserves original history','p_chave_idempotencia':uid()}
    r.deny('adicionar_versao_documento_competencia_v115',edit)
    second=r.operation('adicionar_versao_documento_competencia_v115',edit);v2=r.entity('version2',second['id_versao'])
    r.check('COMP_DOC_VERSION_REPLAY',r.operation('adicionar_versao_documento_competencia_v115',edit)==second)
    wait_document(r,second,second_file,'competencia')
    r.operation('adicionar_versao_documento_competencia_v115',{**edit,'p_motivo':'divergent'},status=409,code='PT409')
    read_payload={'p_id_competencia':c,'p_documentos_offset':0,'p_documentos_limite':25,'p_requisitos_offset':0,'p_requisitos_limite':25}
    r.operation('obter_documentos_competencia_v115',read_payload,'usuario_b',status=403,code='42501')
    st,_=r.request('/rest/v1/rpc/obter_documentos_competencia_v115',read_payload)
    r.check('COMP_DOC_OFFICIAL_ANON_DENIED',st in (401,403),st)
    for role in ('administrador','leitor'):
        view=r.operation('obter_documentos_competencia_v115',read_payload,role)
        docs=view['documentos']
        r.check('COMP_DOC_OFFICIAL_READ',len(docs)==1 and docs[0]['id']==doc and docs[0]['versao_atual']==2 and docs[0]['versao']['id']==v2 and docs[0]['arquivo']['id']==second_file and view['documentos_paginacao']['total']==1)
    r.operation('obter_documentos_competencia_v115',{**read_payload,'p_documentos_limite':None},status=400,code='PT400')
    r.check('COMP_DOC_READER_READ',len(r.read('documentos_competencia',{'select':'id','id':'eq.'+doc},'leitor'))==1)
    r.check('COMP_DOC_TENANT_ISOLATED',r.read('versoes_documento',{'select':'id','id_documento_competencia':'eq.'+doc},'usuario_b')==[])
    r.sql_check('COMP_DOC_SQL_HISTORY','select exists(select 1 from public.documentos_competencia where id='+q(doc)+' and id_competencia='+q(c)+' and id_organizacao='+q(f['org'])+" and versao_atual=2) and (select count(*)=2 and min(numero_versao)=1 and max(numero_versao)=2 from public.versoes_documento where id_documento_competencia="+q(doc)+') and exists(select 1 from public.versoes_documento where id='+q(v1)+' and id_arquivo='+q(file)+') and exists(select 1 from public.versoes_documento where id='+q(v2)+' and id_arquivo='+q(second_file)+" and motivo_substituicao='Own correction preserves original history');")
    r.sql_check('COMP_DOC_AUDIT','select count(*)=2 from public.eventos_auditoria where id_organizacao='+q(f['org'])+" and evento in ('DocumentoCompetenciaCriado','VersaoDocumentoCompetenciaCriada');")
