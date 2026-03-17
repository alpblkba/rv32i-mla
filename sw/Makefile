CC ?= gcc
AR ?= ar

CFLAGS ?= -D_DEFAULT_SOURCE -Wall -Wextra -Wpedantic -std=c11 -O2 -Iinclude
LDFLAGS ?=
LDLIBS ?=

BUILD_DIR := build
APP_DIR := apps
SRC_DIR := src
INC_DIR := include

LIB_NAME := rv32i_mla
APP_NAME := rv32i_mla_app

LIB_OBJ := $(BUILD_DIR)/rv32i_mla.o
APP_OBJ := $(BUILD_DIR)/rv32i_mla_app.o
STATIC_LIB := $(BUILD_DIR)/lib$(LIB_NAME).a
APP := $(BUILD_DIR)/$(APP_NAME)

.PHONY: all clean dirs run_info run_ps_sanity run_smoke run_no_branch run_branch_only run_jump_only run_results

all: dirs $(STATIC_LIB) $(APP)

dirs:
	mkdir -p $(BUILD_DIR)

$(LIB_OBJ): $(SRC_DIR)/rv32i_mla.c $(SRC_DIR)/rv32i_mla_priv.h $(INC_DIR)/rv32i_mla.h
	$(CC) $(CFLAGS) -c $< -o $@

$(STATIC_LIB): $(LIB_OBJ)
	$(AR) rcs $@ $^

$(APP_OBJ): $(APP_DIR)/rv32i_mla_app.c $(INC_DIR)/rv32i_mla.h
	$(CC) $(CFLAGS) -c $< -o $@

$(APP): $(APP_OBJ) $(STATIC_LIB)
	$(CC) $(APP_OBJ) $(STATIC_LIB) $(LDFLAGS) $(LDLIBS) -o $@

run_info: $(APP)
	./$(APP) info

run_ps_sanity: $(APP)
	./$(APP) ps_sanity

run_smoke: $(APP)
	./$(APP) smoke

run_no_branch: $(APP)
	./$(APP) no_branch

run_branch_only: $(APP)
	./$(APP) branch_only

run_jump_only: $(APP)
	./$(APP) jump_only

run_results: $(APP)
	./$(APP) results

clean:
	rm -rf $(BUILD_DIR)
