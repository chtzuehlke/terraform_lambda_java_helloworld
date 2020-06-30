package com.demo.lambda;

import static org.junit.Assert.*;

import org.junit.Test;

public class HandlerTest {
	@Test
	public void test() {
		assertEquals("Hallo Welt", new Handler().helloMessage());
	}
}
