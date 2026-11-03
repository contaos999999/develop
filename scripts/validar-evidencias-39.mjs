import { readFileSync } from 'node:fs';
const index=JSON.parse(readFileSync('docs/prompts/INDICE_EVIDENCIAS_INDIVIDUAIS_39_2026-11-03.json','utf8'));
const tracker=JSON.parse(readFileSync('docs/prompts/PLANO_SANEAMENTO_39_PROMPTS_2026-11-03.json','utf8'));
if(index.total!==39||index.indice.length!==39||tracker.rows.length!==39) throw Error('Quantidade divergente de prompts');
for(let i=0;i<39;i++){
 const id=String(i).padStart(2,'0'),path='docs/prompts/evidencias_individuais/PROMPT_'+id+'.json';
 const item=JSON.parse(readFileSync(path,'utf8')),reg=tracker.rows[i];
 if(item.id!==id||reg.prompt_id!==id||reg.dossie_individual!==path||index.indice[i].fonte!==path)throw Error('Identificador ou caminho divergente: '+id);
 if(!Array.isArray(item.evidencias)||item.evidencias.length===0)throw Error('Sem evidências: '+id);
 if(!Array.isArray(item.acoes_de_fechamento)||item.acoes_de_fechamento.length===0)throw Error('Sem ações: '+id);
 if(item.certificacao_integral!==false||reg.prova_100_por_prompt!==false)throw Error('Certificação integral declarada sem prova: '+id);
}
console.log('PASS DOCUMENTAL: 39/39 dossiês presentes e rastreados; 0/39 certificações integrais. Este teste não executa fluxos funcionais.');
