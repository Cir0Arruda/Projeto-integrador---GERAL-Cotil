// ============================================================================
// ★ DICIONÁRIO DE RÓTULOS E CORES VISUAIS (LABELS.DART) ★
// Traduz códigos técnicos do banco de dados (en-US) em português claro e
// define as cores bonitinhas dos badges (verde, amarelo, vermelho)! (✿◠‿◠)
// 1) Papéis de usuários (admin, gerente, operador) :3
// 2) Níveis de estoque (OK, Crítico, Zerado) (｡•̀ᴗ-)✧
// 3) Prioridades e status de manutenção das máquinas (*¯︶¯*)
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/wms_models.dart';

// Traduz o cargo do usuário para exibição amigável :3
String roleLabel(String role) => switch (role) {
      'superadmin' => 'Proprietário',
      'admin' => 'Administrador',
      'manager' => 'Gerente',
      'operator' => 'Operador',
      'viewer' => 'Leitor',
      _ => role,
    };

// Cor representativa para a etiqueta do cargo (✿◠‿◠)
Color roleColor(String role) => switch (role) {
      'superadmin' => const Color(0xFF6366F1),
      'admin' => AppColors.brand,
      'manager' => AppColors.info,
      'operator' => AppColors.warning,
      _ => AppColors.textMuted,
    };

// Rótulo de alerta para o estoque :3
String stockLevelLabel(StockLevel level) => switch (level) {
      StockLevel.healthy => 'OK :3',
      StockLevel.low => 'CRÍTICO (TwT)',
      StockLevel.empty => 'ZERADO ;-; ',
    };

// Cor do semáforo de estoque (verde = OK, amarelo = baixo, vermelho = zerado) (｡•̀ᴗ-)✧
Color stockLevelColor(StockLevel level) => switch (level) {
      StockLevel.healthy => AppColors.brand,
      StockLevel.low => AppColors.warning,
      StockLevel.empty => AppColors.danger,
    };

// Prioridade da tarefa de manutenção :3
String priorityLabel(String priority) => switch (priority) {
      'critical' => 'Crítica',
      'high' => 'Alta',
      'medium' => 'Média',
      'low' => 'Baixa',
      _ => priority,
    };

// Cores de urgência para a ordem de serviço (*¯︶¯*)
Color priorityColor(String priority) => switch (priority) {
      'critical' => AppColors.danger,
      'high' => AppColors.warning,
      'medium' => AppColors.info,
      _ => AppColors.textMuted,
    };

// Tipo de manutenção (preventiva, corretiva, etc) :3
String workTypeLabel(String type) => switch (type) {
      'preventive' => 'Preventiva',
      'corrective' => 'Corretiva',
      'inspection' => 'Inspeção',
      _ => type,
    };

// Status do andamento da ordem de serviço (✿◠‿◠)
String workStatusLabel(String status) => switch (status) {
      'open' => 'Aberta',
      'planned' => 'Planejada',
      'released' => 'Liberada',
      'in_progress' => 'Em execução',
      'completed' => 'Concluída',
      'closed' => 'Encerrada',
      'cancelled' => 'Cancelada',
      _ => status,
    };

// Cor do status da ordem de serviço :3
Color workStatusColor(String status) => switch (status) {
      'completed' || 'closed' => AppColors.brand,
      'in_progress' || 'released' => AppColors.info,
      'cancelled' => AppColors.textMuted,
      _ => AppColors.warning,
    };

// Estado operacional da máquina :3
String assetStatusLabel(String status) => switch (status) {
      'active' => 'Ativo',
      'inactive' => 'Inativo',
      'maintenance' => 'Em manutenção',
      'retired' => 'Desativado',
      _ => status,
    };

// Cor da máquina (verde = rodando feliz, amarelo = em conserto) (｡•̀ᴗ-)✧
Color assetStatusColor(String status) => switch (status) {
      'active' => AppColors.brand,
      'maintenance' => AppColors.warning,
      _ => AppColors.textMuted,
    };
