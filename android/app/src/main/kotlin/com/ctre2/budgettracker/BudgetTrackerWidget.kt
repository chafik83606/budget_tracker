package com.ctre2.budgettracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class BudgetTrackerWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.budget_tracker_widget)

            val month = widgetData.getString("month_label", "Budget Tracker") ?: "Budget Tracker"
            val balance = widgetData.getString("balance", "—") ?: "—"
            val incomes = widgetData.getString("incomes", "—") ?: "—"
            val expenses = widgetData.getString("expenses", "—") ?: "—"

            views.setTextViewText(R.id.widget_month, month)
            views.setTextViewText(R.id.widget_balance, balance)
            views.setTextViewText(R.id.widget_incomes, "Rev. $incomes")
            views.setTextViewText(R.id.widget_expenses, "Dep. $expenses")

            val addIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                android.net.Uri.parse("budgettracker://add"),
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, addIntent)

            val openIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                android.net.Uri.parse("budgettracker://home"),
            )
            views.setOnClickPendingIntent(R.id.widget_balance, openIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
