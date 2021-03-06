#!/bin/bash

#by Ajaxx

array_diretorios=("")
declare -a array_cont
colunas=$(tput cols) # VERIFICA O TAMANHO DA JANELA PARA PODER DESENHAR O LAYOUT
#=================================================================================================================

function uso() {
	divisao
	printf "\033[37;1mAjaxx Web Recon\n\033[m"
	printf "\033[37;1mUso: $0 <opcoes>\n\033[m"
	printf "\033[37;1mOpcoes:\n\033[m"
	printf "\033[37;1m	-u url				URL base a ser pesquisada\n\033[m"
	printf "\033[37;1m	-w wordlist			Wordlist utilizada na pesquisa\n\033[m"
	printf "\033[37;1m	-a \"user-agent\"			String User Agent [opcional]\n\033[m"
	printf "\033[37;1m	-x extensao,extensao...		Pesquisa por extensoes [opcional]\n\033[m"
	printf "\033[37;1m	-d profundidade			Profundidade da pesquisa (numerico, min=1) [opcional]\n\033[m"
	divisao
	exit 1
}
#=================================================================================================================

divisao () {
	printf "\r\033[35;1m=\033[m"

	# LACO PARA PREENCHER UMA LINHA COM "="
	for i in $(seq 0 1 $(($colunas-2)))
	do
		printf "\033[35;1m=\033[m"
	done
	echo
}
#=================================================================================================================

diretorios () { # PROCURA POR DIRETORIOS
	resposta=$(curl -s -A "$agent" -o /dev/null -w '%{http_code}' $1/$2/)
	if [ $resposta == "200" ]
	then
		printf "\r\033[32;1m$3[+] Diretorio encontrado:\033[36;1m $1/$2\n\033[m"
		
		# CADA DIRETORIO EXISTENTE EH ADICIONADO A UM ARRAY PARA POSTERIOR PESQUISA DE ARQUIVOS NO MESMO
		array_diretorios[$((${#array_diretorios[*]}+1))]=$(echo "$1/$2" | cut -d "/" -f 2-)
		
		# CONTROLA A PROFUNDIDADE
		if [ $contador -lt $deep ] 
		then
			contador=$((contador+1))
			array_cont[$((${#array_cont[*]}+1))]=1
			for diretorio in $(cat $wordlist)
			do	
				# IDENTACAO DOS DIRETORIOS
				espaco=$3
				espaco=$(echo "$espaco-")
				cor=$((30+${#array_cont[*]}))
				
				printf "\r\033[$cor;1m$espaco>${array_cont[${#array_cont[*]}]} de $nomes nomes em \033[36;1m/$2     \033[m" # CONTADOR DE NOMES
				diretorios "$1/$2" $diretorio $espaco
				array_cont[${#array_cont[*]}]=$((${array_cont[${#array_cont[*]}]}+1))
			done
			unset array_cont[${#array_cont[*]}] # APAGA A ULTIMA POSICAO DO ARRAY CONTADOR PARA PODER RETOMAR O CONTADOR ANTERIOR
		fi
	fi
}
#=================================================================================================================

arquivos () { # PROCURA POR ARQUIVOS
	# PESQUISA PELOS NOMES DA WORDLIST SEM EXTENSAO
	resposta=$(curl -s -A "$agent" -o /dev/null -w '%{http_code}' $1/$2)
	if [ $resposta == "200" ]
	then
		printf "\r\033[33;1m$3|- Arquivo encontrado:\033[37;1m $1/$2\n\033[m"
	fi
	# PESQUISA PELOS NOMES DA WORDLIST COM EXTENSAO
	for extensao in "${array_extensao[@]}"
	do
		resposta=$(curl -s -A "$agent" -o /dev/null -w '%{http_code}' $1/$2.$extensao)
		if [ $resposta == "200" ]
		then
			printf "\r\033[33;1m$3|- Arquivo $extensao encontrado:\033[37;1m $1/$2.$extensao\n\033[m"
		fi
	done
}
#=================================================================================================================

clear

#CHAMA A FUNCAO PARA DESENHAR UMA DIVISORIA
divisao
echo

centro_coluna=$(( $(( $(( $colunas-16))/2 )))) #CALCULO PARA CENTRALLIZAR O TITULO
tput cup 0 $centro_coluna #POSICIONAR O CURSOR
printf "\033[37;1mLAjaxx WEB RECON\n\033[m"

deep=9999
agent="AjaxxWeb"
cor=31
declare -a array_extensao

# VERIFICA AS OPCOES DIGITADAS
while getopts "hu:w:x:d:a:" OPTION
do
	case $OPTION in
    	"h") uso
        	;;
      	"u") url=$OPTARG
         	;;
      	"w") wordlist=$OPTARG
	  		# QUANTIDADE DE NOMES NA WORDLIST
			nomes=$(wc -l $wordlist | cut -d " " -f 1)
         	;;
      	"x") IFS=' , ' read -r -a array_extensao <<< "$OPTARG"
        	;;
      	"d") deep=$OPTARG
        	;;
		"a") agent=$OPTARG
        	;;
      	"?") uso
        	;;
   esac
done
shift $((OPTIND-1))

echo $extensao

# VERIFICA SE FORAM DIGITADOS OS PARAMETROS OBRIGATORIOS -u E -w
[ -z "$url" -o -z "$wordlist" ] && uso

# VERIFICA SE O PARAMETRO -d EH NUMERICO
numeric='^[0-9]+$'
if ! [[ $deep =~ $numeric ]] ; then
   	printf "\033[31;1m[-] A profundidade deve ser numeria maior que 0!\n\033[m"
   	uso
fi

# VERIFICA SE A WORDLIST EXISTE
if [ ! -f "$wordlist" ]
then
	printf "\033[31;1m[-] Verifique a WORDLIST digitada!\n\033[m"
	uso
fi

# VERIFICA SE A URL NAO EXISTE OU NAO ESTA RESPONDENDO
status=$(curl -s -A "$agent" -I $url)
if [ "$status" == "" ]
then
	printf "\033[31;1m[-] Verifique a URL digitada!\n\033[m"
	uso
fi

# BUSCA INFORMACOES PARA OBTER O SERVER E A TECNOLOGIA UTILIZADA NAS PAGINAS
server=$(echo "$status" | grep -E "Server:" | cut -d ":" -f 2)
tecnologia=$(echo "$status" | grep -E "X-Powered-By" | cut -d ":" -f 2)
printf "\033[32;1m[+] WebServer identificado:\033[36;1m$server\n\033[m"
if [[ $tecnologia != "" ]]
then
	printf "\033[32;1m[+] Tecnologias:\033[36;1m$tecnologia\n\033[m"
fi

divisao
printf "\033[37;1m[+] Buscando por Diretorios\n\033[m"
divisao

# BUSCA POR DIRETORIOS
array_cont[0]=1
cont=1
for diretorio in $(cat $wordlist)
do
	contador=1
	printf "\r\033[31;1m>${array_cont[0]} de $nomes nomes em \033[36;1m/     \033[m" # CONTADOR DE NOMES
	diretorios $url $diretorio ""
	array_cont[0]=$((${array_cont[0]}+1))
done

divisao

# SE FOR DIGITADO O TERCEIRO PARAMETRO (EXTENSAO) PESQUISA POR ARQUIVOS NA RAIZ E EM CADA DIRETORIO ENCONTRADO, UTILIZANDO A MESMA WORDLIST
if [ ! -z ${#extensao[*]} ]
then
for elemento in "${array_diretorios[@]}"
do
	printf "\033[37;1m[+] Buscando por Arquivos em \033[36;1m$1/$elemento\n\033[m"
	cont=1
	for arquivo in $(cat $wordlist)
	do		
		printf "\r\033[31;1m>$cont de $nomes nomes\033[m" # CONTADOR DE NOMES	
		if [ -z "$elemento" ]
		then
			arquivos "$url" $arquivo " "
		else
			arquivos "$url/$elemento" $arquivo " "
		fi
		cont=$(($cont+1))
	done
	divisao
done
fi
echo
