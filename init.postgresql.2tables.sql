-- UNLOGGED?
CREATE  TABLE clientes (
	id SERIAL PRIMARY KEY,
	nome VARCHAR(255) NOT NULL,
	limite INTEGER NOT NULL,
	saldo INTEGER NOT NULL DEFAULT 0
);

CREATE  TABLE transacoes (
	id SERIAL PRIMARY KEY,
	cliente_id INTEGER NOT NULL,
	valor INTEGER NOT NULL,
	tipo CHAR(1) NOT NULL,
	descricao CHAR(10) NOT NULL,
	realizada_em TIMESTAMP(6) NOT NULL DEFAULT NOW(),
	CONSTRAINT fk_clientes_transacoes_id
		FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);

INSERT INTO clientes (nome, limite) VALUES
	('o barato sai caro', 1000 * 100),
	('zan corp ltda', 800 * 100),
	('les cruders', 10000 * 100),
	('padaria joia de cocaia', 100000 * 100),
	('kid mais', 5000 * 100);

CREATE EXTENSION IF NOT EXISTS pg_prewarm;
-- SELECT pg_prewarm('clientes');
-- SELECT pg_prewarm('transacoes');



CREATE TYPE transacao_result AS (saldo INT, limite INT);

CREATE OR REPLACE FUNCTION proc_transacao(p_cliente_id INT, p_valor INT, p_tipo CHAR, p_descricao CHAR(10))
RETURNS transacao_result as $$
DECLARE
    diff INT;
    v_saldo INT;
    v_limite INT;
    result transacao_result;
BEGIN
    -- PERFORM pg_advisory_lock(p_id);
    PERFORM pg_try_advisory_xact_lock(p_cliente_id);
    -- PERFORM pg_advisory_xact_lock(p_id);
    -- lock table clientes in ACCESS EXCLUSIVE mode;
    -- lock table transacoes in ACCESS EXCLUSIVE mode;


    SELECT saldo, limite
        INTO v_saldo, v_limite
        FROM clientes
        WHERE id = p_cliente_id;

    IF p_tipo = 'd' THEN
        diff := p_valor * -1;
        IF (v_saldo + diff) < (-1 * v_limite) THEN
            RAISE 'LIMITE_INDISPONIVEL [%, %, %]', v_saldo, diff, v_limite;
        END IF;
    ELSE
        diff := p_valor;
    END IF;
    
    INSERT INTO transacoes 
                     (cliente_id,   valor,   tipo,   descricao,      realizada_em)
            VALUES (p_cliente_id, p_valor, p_tipo, p_descricao, CURRENT_TIMESTAMP);

    UPDATE clientes 
        SET saldo = saldo + diff 
        WHERE id = p_cliente_id
        RETURNING saldo, limite INTO v_saldo, v_limite;

    result := (v_saldo, v_limite)::transacao_result;
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        RAISE 'Error processing transaction: %', SQLERRM;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION proc_extrato(p_id integer)
RETURNS json AS $$
DECLARE
    result json;
    row_count integer;
    v_saldo numeric;
    v_limite numeric;
BEGIN
    PERFORM pg_try_advisory_xact_lock(p_id);
    -- PERFORM pg_try_advisory_lock(p_id);
    -- PERFORM pg_advisory_xact_lock(p_id);
    -- lock table clientes in ACCESS EXCLUSIVE mode;
    -- lock table transacoes in ACCESS EXCLUSIVE mode;

    SELECT saldo, limite
        INTO v_saldo, v_limite
        FROM clientes
        WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CLIENTE_NAO_ENCONTRADO %', p_id;
    END IF;

    SELECT json_build_object(
        'saldo', json_build_object(
            'total', v_saldo,
            'data_extrato', TO_CHAR(NOW(), 'YYYY-MM-DD HH:MI:SS.US'),
            'limite', v_limite
        ),
        'ultimas_transacoes', COALESCE((
            SELECT json_agg(row_to_json(t)) FROM (
                SELECT valor, tipo, descricao, TO_CHAR(realizada_em, 'YYYY-MM-DD HH:MI:SS.US') as realizada_em
                FROM transacoes
                WHERE cliente_id = p_id
                ORDER BY realizada_em DESC
                -- ORDER BY id DESC
                LIMIT 10
            ) t
        ), '[]')
    ) INTO result;

    RETURN result;
END;
$$ LANGUAGE plpgsql;
-- SQL init done