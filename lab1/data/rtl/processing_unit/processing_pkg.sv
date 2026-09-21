package processing_pkg;
	typedef enum bit [1:0] {
		SUM = 2'b00,
		SUB = 2'b01,
		XOR = 2'b10,
		MUL = 2'b11
	} operation_e;
endpackage