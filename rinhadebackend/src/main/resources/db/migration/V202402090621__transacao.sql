CREATE TYPE transacao_result AS (saldo INT, limite INT);

CREATE OR REPLACE FUNCTION proc_transacao(p_cliente_id INT, p_valor INT, p_tipo VARCHAR, p_descricao VARCHAR)
RETURNS transacao_result as $$
DECLARE
    diff INT;
    v_saldo INT;
    v_limite INT;
    result transacao_result;
BEGIN
    IF p_tipo = 'd' THEN
        diff := p_valor * -1;
    ELSE
        diff := p_valor;
    END IF;

    -- Is this necessary?
    PERFORM * FROM clientes WHERE id = p_cliente_id FOR UPDATE;


    UPDATE clientes 
        SET saldo = saldo + diff 
        WHERE id = p_cliente_id
        RETURNING saldo, limite INTO v_saldo, v_limite;

    IF (v_saldo + diff) < (-1 * v_limite) THEN
        RAISE 'LIMITE_INDISPONIVEL [%, %, %]', v_saldo, diff, v_limite;
    ELSE
        result := (v_saldo, v_limite)::transacao_result;
        INSERT INTO transacoes (cliente_id, valor, tipo, descricao)
            VALUES (p_cliente_id, p_valor, p_tipo, p_descricao);
        RETURN result;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE 'Error processing transaction: %', SQLERRM;
        ROLLBACK;
END;
$$ LANGUAGE plpgsql;