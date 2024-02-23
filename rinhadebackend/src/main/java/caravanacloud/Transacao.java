package caravanacloud;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Comparator;


public class Transacao implements Serializable{
    public int valor;
    public String tipo;
    public String descricao;
    public LocalDateTime realizadaEm;

    public LocalDateTime getRealizadaEm() {
        return realizadaEm;
    }

    static class TransacaoComparator implements Serializable, Comparator<Transacao> {
      @Override
        public int compare(Transacao o1, Transacao o2) {
            return o2.realizadaEm.compareTo(o1.realizadaEm);
        }
        
    }

    public static final TransacaoComparator comparator = new TransacaoComparator();
    

    public static Transacao of(int valor2, String tipo2, String descricao2, LocalDateTime realizadaEm) {
        var t = new Transacao();
        t.valor = valor2;
        t.tipo = tipo2;
        t.descricao = descricao2;
        t.realizadaEm = realizadaEm;
        return t;
    }
}
